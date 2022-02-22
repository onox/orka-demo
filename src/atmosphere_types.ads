with GL.Types;

with Orka.Behaviors;

with Integrators.RK4;

package Atmosphere_Types is

   type No_Behavior is new Orka.Behaviors.Behavior with record
      Position : Orka.Behaviors.Vector4 := Orka.Behaviors.Null_Behavior.Position;
   end record;

   overriding
   function Position (Object : No_Behavior) return Orka.Behaviors.Vector4 is (Object.Position);

   -----------------------------------------------------------------------------

   type Gravity_Object is new Integrators.Physics_Object with private;

   function Altitude (Object : Gravity_Object) return Orka.Float_64;

   procedure Set_Mass (Object : in out Gravity_Object; Value : Orka.Float_64);

   procedure Set_Gravity (Object : in out Gravity_Object; Value : Orka.Float_64);

   procedure Set_Thrust (Object : in out Gravity_Object; Value : Orka.Float_64);

   overriding
   procedure Update
     (Object : in out Gravity_Object;
      State  : Integrators.Integrator_State;
      Delta_Time : Duration);

   overriding
   function Forces (Object : Gravity_Object) return Integrators.Force_Array_Access;

   overriding
   function Moments (Object : Gravity_Object) return Integrators.Moment_Array_Access;

   overriding
   function Inverse_Mass (Object : Gravity_Object) return Orka.Float_64;

   overriding
   function Inverse_Inertia (Object : Gravity_Object) return Orka.Float_64;

   overriding
   function Center_Of_Mass (Object : Gravity_Object) return Integrators.Vectors.Vector4;

   -----------------------------------------------------------------------------

   protected type Integrator is
      procedure Initialize
        (FDM : Integrators.Physics_Object'Class;
         Position, Velocity : Orka.Behaviors.Vector4;
         Orientation : Integrators.Quaternions.Quaternion);

      procedure Update
        (FDM : in out Integrators.Physics_Object'Class;
         Delta_Time : Duration);

      function State return Integrators.Integrator_State;
   private
      RK4 : Integrators.RK4.RK4_Integrator;
      T   : Orka.Float_64 := 0.0;
   end Integrator;

   type Frame_Type is (ECI, ECEF);

   type Physics_Behavior (Frame : Frame_Type)
     is limited new Orka.Behaviors.Behavior with
   record
      FDM : Gravity_Object;
      Int : Integrator;
   end record;

   overriding
   function Position (Object : Physics_Behavior) return Orka.Behaviors.Vector4;

   overriding
   procedure Fixed_Update (Object : in out Physics_Behavior; Delta_Time : Duration);

private

   type Gravity_Object is new Integrators.Physics_Object with record
      F_Gravity      : Integrators.Vectors.Vector4 :=
        Integrators.Vectors.Vector4 (Integrators.Vectors.Zero_Direction);
      F_Anti_Gravity : Integrators.Vectors.Vector4 :=
        Integrators.Vectors.Vector4 (Integrators.Vectors.Zero_Direction);

      Altitude : Orka.Float_64 := 0.0;

      Mass     : Orka.Float_64 := 1.0;
      Gravity  : Orka.Float_64 := 0.0;
      Thrust   : Orka.Float_64 := 0.0;
   end record;

end Atmosphere_Types;
