with Coordinates;
with Planets.Earth;

package body Atmosphere_Types is

   Hit_Detection : constant Boolean := True;

   use type Orka.Float_64;

   procedure Set_Mass (Object : in out Gravity_Object; Value : Orka.Float_64) is
   begin
      Object.Mass := Value;
   end Set_Mass;

   procedure Set_Gravity (Object : in out Gravity_Object; Value : Orka.Float_64) is
   begin
      Object.Gravity := Value;
   end Set_Gravity;

   procedure Set_Thrust (Object : in out Gravity_Object; Value : Orka.Float_64) is
   begin
      Object.Thrust := Value;
   end Set_Thrust;

   function Altitude (Object : Gravity_Object) return Orka.Float_64 is (Object.Altitude);

   overriding
   procedure Update
     (Object : in out Gravity_Object;
      State  : Integrators.Integrator_State;
      Delta_Time : Duration)
   is
      use Integrators.Vectors;

      Earth_Center : constant Vector4 := Vector4 (Zero_Point);

      Direction_Down : constant Vector4 :=
        Normalize (Earth_Center - State.Position);
      Direction_Up : constant Vector4 :=
        Normalize (State.Position - Earth_Center);

      Gravity : Vector4 :=
        Direction_Down * (Object.Gravity * Object.Mass);

      --      GM
      --  g = ---
      --      r^2
      --
      --  g0 = GM/Re^2
      --
      --  g = g0 * (Re^2)/(Re + z)^2 = g0 / (1.0 + z/Re)^2
      --
      --  z = altitude above sea level

      Distance_To_Center : constant Orka.Float_64 :=
        Integrators.Vectors.Length (State.Position - Earth_Center);
      Radius_To_Center : constant Orka.Float_64 :=
        Planets.Earth.Planet.Radius (Direction_Up);
        --  FIXME Direction_Up is already flattened
   begin
      Integrators.Quaternions.Rotate_At_Origin
        (Gravity, Integrators.Quaternions.Conjugate (State.Orientation));

      if Hit_Detection and Distance_To_Center <= Radius_To_Center then
         declare
            Inverse_DT : constant Orka.Float_64 := (1.0 / Orka.Float_64 (Delta_Time));

            New_Momentum : Vector4 := -State.Momentum;
--            New_Momentum : Vector4 := -1.0 * State.Velocity * Object.Mass;
         begin
            Integrators.Quaternions.Rotate_At_Origin
              (New_Momentum, Integrators.Quaternions.Conjugate (State.Orientation));

            --  FIXME Doesn't bounce on the surface of the planet
            --  FIXME Doesn't respect rotational velocity of surface
            Object.F_Anti_Gravity := New_Momentum * Inverse_DT;
            Object.F_Gravity      := Vector4 (Zero_Direction);
         end;

         --  v1' = (m1 - m2)/(m1 + m2) * v1
         --  v2' = (2*m1)/(m1 + m2) * v1
         --
         --  v1' = v1       v2' = 2*v1        m1 >> m2    m2 => 0
         --  v1' = -v1      v2' = 0           m1 << m2    m1 => 0
         --  v1' = 0        v2' = v1          m1 = m2

         --  m1v1 = m1v1' + m2v2'
      else
         Object.F_Anti_Gravity := Vector4 (Zero_Direction);
         Object.F_Gravity      := Gravity;
      end if;
      Object.Altitude := Distance_To_Center - Radius_To_Center;
   end Update;

   overriding
   function Forces (Object : Gravity_Object) return Integrators.Force_Array_Access is
      Forces : constant Integrators.Force_Array_Access := new Integrators.Force_At_Point_Array'
        (1 => (Force => Object.F_Gravity,
               Point => Object.Center_Of_Mass),
         2 => (Force => Object.F_Anti_Gravity,
               Point => Object.Center_Of_Mass),
         3 => (Force => (Object.Thrust, 0.0, 0.0, 0.0),
               Point => Object.Center_Of_Mass));
   begin
      return Forces;
   end Forces;

   overriding
   function Moments (Object : Gravity_Object) return Integrators.Moment_Array_Access is
      Moments : constant Integrators.Moment_Array_Access := new Integrators.Moment_Array (1 .. 0);
   begin
      return Moments;
   end Moments;

   overriding
   function Inverse_Mass (Object : Gravity_Object) return Orka.Float_64 is
     (1.0 / Object.Mass);

   overriding
   function Inverse_Inertia (Object : Gravity_Object) return Orka.Float_64 is
     (8.643415877954968e-05);

   overriding
   function Center_Of_Mass (Object : Gravity_Object) return Integrators.Vectors.Vector4 is
     ((0.0, 0.0, 0.0, 1.0));

   ----------------------------------------------------------------------------

   protected body Integrator is
      procedure Initialize
        (FDM : Integrators.Physics_Object'Class;
         Position, Velocity : Orka.Behaviors.Vector4;
         Orientation : Integrators.Quaternions.Quaternion) is
      begin
         RK4 := Integrators.RK4.Create_Integrator
           (FDM, Position => Position, Velocity => Velocity, Orientation => Orientation);
      end Initialize;

      procedure Update
        (FDM : in out Integrators.Physics_Object'Class;
         Delta_Time : Duration)
      is
         DT : constant Orka.Float_64 := Orka.Float_64 (Delta_Time);
      begin
         RK4.Integrate (FDM, T, DT);
         T := T + DT;
      end Update;

      function State return Integrators.Integrator_State is (RK4.State);
   end Integrator;

   overriding
   function Position (Object : Physics_Behavior) return Orka.Behaviors.Vector4 is
      use Coordinates.Matrices;
   begin
      case Object.Frame is
         when ECI =>
            return Coordinates.Rotate_ECI * Object.Int.State.Position;
         when ECEF =>
            return Coordinates.Rotate_ECEF * Object.Int.State.Position;
      end case;
   end Position;

   overriding
   procedure Fixed_Update (Object : in out Physics_Behavior; Delta_Time : Duration) is
   begin
      Object.Int.Update (Object.FDM, Delta_Time);
   end Fixed_Update;

end Atmosphere_Types;
