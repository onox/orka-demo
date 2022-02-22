with Orka;

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

      procedure Update (State : in out Linear_State; Motion : Derivative; DT : Double) is
      begin
         State.Position := State.Position + Motion.DX * DT;
         State.Momentum := State.Momentum + Motion.DP * DT;

         --  Recompute velocity after updating momentum
         State.Velocity := State.Momentum * State.Inverse_Mass;
      end Update;

      function Evaluate
        (Initial : Linear_State;
         Force   : not null access function
           (State : Linear_State; Time : Double) return Vectors.Vector4;
         T, DT   : Double;
         Motion  : Derivative) return Derivative
      is
         Next : Linear_State := Initial;
      begin
         Update (Next, Motion, DT);

         return Result : Derivative do
            Result.DX := Next.Velocity;
            Result.DP := Force (Next, T + DT);
         end return;
      end Evaluate;

      procedure Integrate
        (Current : in out Linear_State;
         Force   : not null access function
           (State : Linear_State; Time : Double) return Vectors.Vector4;
         T, DT   : Double)
      is
         Initial, A, B, C, D : Derivative;
         DX_DT, DP_DT : Vectors.Vector4;
      begin
         A := Evaluate (Current, Force, T, 0.0, Initial);
         B := Evaluate (Current, Force, T, DT * 0.5, A);
         C := Evaluate (Current, Force, T, DT * 0.5, B);
         D := Evaluate (Current, Force, T, DT, C);

         DX_DT := 1.0 / 6.0 * (A.DX + 2.0 * (B.DX + C.DX) + D.DX);
         DP_DT := 1.0 / 6.0 * (A.DP + 2.0 * (B.DP + C.DP) + D.DP);

         Update (Current, (DX => DX_DT, DP => DP_DT), DT);
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

      procedure Update (State : in out Angular_State; Motion : Derivative; DT : Double) is
      begin
         State.Orientation      := Q (V (State.Orientation) + V (Motion.Spin) * DT);
         State.Angular_Momentum := State.Angular_Momentum + Motion.Torque * DT;

         --  Recompute angular velocity after updating angular momentum
         State.Angular_Velocity := State.Angular_Momentum * State.Inverse_Inertia;
         State.Orientation := Quaternions.Normalize (State.Orientation);
         pragma Assert (Quaternions.Normalized (State.Orientation));
      end Update;

      function Evaluate
        (Initial : Angular_State;
         Torque  : not null access function
           (State : Angular_State; Time : Double) return Vectors.Vector4;
         T, DT   : Double;
         Motion  : Derivative) return Derivative
      is
         Next : Angular_State := Initial;
      begin
         Update (Next, Motion, DT);

         return Result : Derivative do
            Result.Spin   := Q (0.5 * V (Quaternion (Next.Angular_Velocity) * Next.Orientation));
            Result.Torque := Torque (Next, T + DT);
         end return;
      end Evaluate;

      procedure Integrate
        (Current : in out Angular_State;
         Torque  : not null access function
           (State : Angular_State; Time : Double) return Vectors.Vector4;
         T, DT   : Double)
      is
         Initial, A, B, C, D : Derivative;
         D_Spin   : Quaternions.Quaternion;
         D_Torque : Vectors.Vector4;
      begin
         A := Evaluate (Current, Torque, T, 0.0, Initial);
         B := Evaluate (Current, Torque, T, DT * 0.5, A);
         C := Evaluate (Current, Torque, T, DT * 0.5, B);
         D := Evaluate (Current, Torque, T, DT, C);

         D_Spin   := Q (1.0 / 6.0 * (V (A.Spin) + 2.0 * (V (B.Spin) + V (C.Spin)) + V (D.Spin)));
         D_Torque := 1.0 / 6.0 * (A.Torque + 2.0 * (B.Torque + C.Torque) + D.Torque);

         Update (Current, (Spin => D_Spin, Torque => D_Torque), DT);
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
