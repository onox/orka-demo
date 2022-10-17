with Orka.Integrators;

package body Integrators.RK4 is

   use Vectors;
   use GL.Types;
   use type Orka.Float_64;

   package Linear_Integrator is
      procedure Integrate
        (Current : in out Linear_State;
         Force   : not null access function
           (State : Linear_State; Time : Double) return Vectors.Vector4;
         T, DT : Double);
   end Linear_Integrator;

   package Angular_Integrator is
      procedure Integrate
        (Current : in out Angular_State;
         Torque  : not null access function
           (State : Angular_State; Time : Double) return Vectors.Vector4;
         T, DT   : Double);
   end Angular_Integrator;

   package body Linear_Integrator is

      type Derivative is record
         DX, DP : Vectors.Vector4 := Vectors.Vector4 (Vectors.Zero_Point);
      end record;

      function "+" (State : Linear_State; Motion : Derivative) return Linear_State is
         Result : Linear_State := State;
      begin
         Result.Position := Result.Position + Motion.DX;
         Result.Momentum := Result.Momentum + Motion.DP;

         --  Recompute velocity after updating momentum
         Result.Velocity := Result.Momentum * Result.Inverse_Mass;

         return Result;
      end "+";

      function "*" (Left : Orka.Float_64; Right : Derivative) return Derivative is
        ((DX => Left * Right.DX, DP => Left * Right.DP));

      function "+" (Left, Right : Derivative) return Derivative is
        ((DX => Left.DX + Right.DX, DP => Left.DP + Right.DP));

      function RK4 is new Orka.Integrators.RK4 (Linear_State, Derivative, Orka.Float_64);

      procedure Integrate
        (Current : in out Linear_State;
         Force   : not null access function
           (State : Linear_State; Time : Orka.Float_64) return Vectors.Vector4;
         T, DT   : Orka.Float_64)
      is
         function F (Y : Linear_State; DT : Orka.Float_64) return Derivative is
           ((DX => Y.Velocity, DP => Force (Y, T + DT)));
      begin
         Current := Current + RK4 (Current, DT, F'Access);
      end Integrate;

   end Linear_Integrator;

   package body Angular_Integrator is

      use Quaternions;

      type Derivative is record
         Spin   : Quaternions.Quaternion := Quaternions.Identity;
         Torque : Vectors.Vector4 := Vectors.Vector4 (Vectors.Zero_Point);
      end record;

      function Quaternion (Value : Vectors.Vector4) return Quaternions.Quaternion is
         use Orka;
      begin
         return Result : Quaternions.Quaternion := Quaternions.Quaternion (Value) do
            Result (W) := 0.0;
         end return;
      end Quaternion;

      function Q (Value : Vectors.Vector4) return Quaternions.Quaternion
        is (Quaternions.Quaternion (Value))
      with Inline;

      function V (Value : Quaternions.Quaternion) return Vectors.Vector4
        is (Vectors.Vector4 (Value))
      with Inline;

      function "+" (State : Angular_State; Motion : Derivative) return Angular_State is
         Result : Angular_State := State;
      begin
         --  FIXME Should we do Result.Orientation := Motion.Spin * Result.Orientation?
         Result.Orientation      := Q (V (Result.Orientation) + V (Motion.Spin));
         Result.Angular_Momentum := Result.Angular_Momentum + Motion.Torque;

         --  Recompute angular velocity after updating angular momentum
         Result.Angular_Velocity := Result.Angular_Momentum * Result.Inverse_Inertia;
         Result.Orientation := Quaternions.Normalize (Result.Orientation);
         pragma Assert (Quaternions.Normalized (Result.Orientation));

         return Result;
      end "+";

      function "*" (Left : Orka.Float_64; Right : Derivative) return Derivative is
        ((Spin => Left * Right.Spin, Torque => Left * Right.Torque));

      function "+" (Left, Right : Derivative) return Derivative is
        ((Spin => Left.Spin + Right.Spin, Torque => Left.Torque + Right.Torque));
      --  FIXME Should we do Spin => Left.Spin * Right.Spin?

      function RK4 is new Orka.Integrators.RK4 (Angular_State, Derivative, Orka.Float_64);

      procedure Integrate
        (Current : in out Angular_State;
         Torque  : not null access function
           (State : Angular_State; Time : Double) return Vectors.Vector4;
         T, DT   : Double)
      is
         function F (Y : Angular_State; DT : Orka.Float_64) return Derivative is
           ((Spin   => Q (0.5 * V (Quaternion (Y.Angular_Velocity) * Y.Orientation)),
             Torque => Torque (Y, T + DT)));
      begin
         Current := Current + RK4 (Current, DT, F'Access);
      end Integrate;

   end Angular_Integrator;

   function Create_Integrator
     (Subject     : Physics_Object'Class;
      Position    : Vectors.Vector4;
      Velocity    : Vectors.Vector4;
      Orientation : Quaternions.Quaternion := Quaternions.Identity) return RK4_Integrator is
   begin
      return Result : RK4_Integrator do
         Result.Linear.Position := Position;
         Result.Linear.Momentum := Velocity * (1.0 / Subject.Inverse_Mass);

         Result.Angular.Orientation := Quaternions.Normalize (Orientation);
      end return;
   end Create_Integrator;

   overriding
   procedure Integrate
     (Object  : in out RK4_Integrator;
      Subject : in out Physics_Object'Class;
      T, DT   : GL.Types.Double)
   is
      Total_Force  : Vectors.Vector4 := Vectors.Vector4 (Vectors.Zero_Direction);
      Total_Torque : Vectors.Vector4 := Vectors.Vector4 (Vectors.Zero_Direction);

      --  FIXME Just provide 2 vectors instead of 2 functions? (only allow time-invariant systems)
      function Force (State : Linear_State; Time : Double) return Vectors.Vector4 is
        (Total_Force);

      function Torque (State : Angular_State; Time : Double) return Vectors.Vector4 is
        (Total_Torque);
   begin
      Subject.Update (Object.State, Duration (DT));

      declare
         Center_Of_Mass : constant Vectors.Vector4 := Subject.Center_Of_Mass;

         Forces : Force_Array_Access := Subject.Forces;
      begin
         for Force_Point of Forces.all loop
            declare
               Force  : Vectors.Vector4 := Force_Point.Force;
               Offset : Vectors.Vector4 := Force_Point.Point - Center_Of_Mass;
            begin
               Quaternions.Rotate_At_Origin (Force, Object.Angular.Orientation);
               Quaternions.Rotate_At_Origin (Offset, Object.Angular.Orientation);
               Total_Force  := Total_Force  + Force;
               Total_Torque := Total_Torque - Vectors.Cross (Force, Offset);
            end;
         end loop;
         Free (Forces);
      exception
         when others =>
            Free (Forces);
            raise;
      end;

      declare
         Moments : Moment_Array_Access := Subject.Moments;
      begin
         for Moment of Moments.all loop
            declare
               Torque : Vectors.Vector4 := Moment;
            begin
               Quaternions.Rotate_At_Origin (Torque, Object.Angular.Orientation);
               Total_Torque := Total_Torque + Torque;
            end;
         end loop;
         Free (Moments);
      exception
         when others =>
            Free (Moments);
            raise;
      end;

      Object.Linear.Inverse_Mass := Subject.Inverse_Mass;
      Object.Angular.Inverse_Inertia := Subject.Inverse_Inertia;

      Linear_Integrator.Integrate (Object.Linear, Force'Access, T, DT);
      Angular_Integrator.Integrate (Object.Angular, Torque'Access, T, DT);
   end Integrate;

   overriding
   function State (Object : RK4_Integrator) return Integrator_State is
     (Position         => Object.Linear.Position,
      Momentum         => Object.Linear.Momentum,
      Velocity         => Object.Linear.Velocity,
      Orientation      => Object.Angular.Orientation,
      Angular_Momentum => Object.Angular.Angular_Momentum,
      Angular_Velocity => Object.Angular.Angular_Velocity);

end Integrators.RK4;
