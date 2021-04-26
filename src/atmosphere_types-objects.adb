with Ada.Numerics.Generic_Elementary_Functions;
with Ada.Text_IO;

with GL.Types;

with Orka.Transforms.Doubles.Matrices;
with Orka.Transforms.Doubles.Quaternions;

with Planets.Earth;

package body Atmosphere_Types.Objects is
   use type GL.Types.Double;

   Gravity_Earth : constant := 9.81;
   --  TODO Gravity should depend on lat/lon

   package Matrices    renames Orka.Transforms.Doubles.Matrices;
   package Quaternions renames Orka.Transforms.Doubles.Quaternions;

   function Q_Yaw (Value : GL.Types.Double) return Quaternions.Quaternion is
   begin
      return Quaternions.R
        (Matrices.Vectors.Normalize ((1.0, 0.0, 0.0, 0.0)),
         Matrices.Vectors.To_Radians (Value));
   end Q_Yaw;

   function Q_Pitch (Value : GL.Types.Double) return Quaternions.Quaternion is
   begin
      return Quaternions.R
        (Matrices.Vectors.Normalize ((0.0, 1.0, 0.0, 0.0)),
         Matrices.Vectors.To_Radians (Value));
   end Q_Pitch;

   function Q_Roll (Value : GL.Types.Double) return Quaternions.Quaternion is
   begin
      return Quaternions.R
        (Matrices.Vectors.Normalize ((1.0, 0.0, 0.0, 0.0)),
         Matrices.Vectors.To_Radians (Value));
   end Q_Roll;

   package EF is new Ada.Numerics.Generic_Elementary_Functions (GL.Types.Double);

   --  Yaw: left
   --  Pitch: up
   --  Roll: right
   procedure Reset
     (Object : Orka.Behaviors.Behavior_Ptr;
      Latitude, Longitude, Altitude : GL.Types.Double;
      Yaw, Pitch, Roll : GL.Types.Double;
      Velocity : Matrices.Vector4;
      Mass, Thrust, Gravity : GL.Types.Double)
   is
      Subject : Atmosphere_Types.Physics_Behavior renames
        Atmosphere_Types.Physics_Behavior (Object.all);

      Init_Position : constant Matrices.Vector4 :=
        Planets.Earth.Planet.Geodetic_To_ECEF (0.0, 0.0, Altitude);
      Init_Lon_Position : constant Matrices.Vector4 :=
        Planets.Earth.Planet.Geodetic_To_ECEF (0.0, Longitude, Altitude);

      Position : constant Matrices.Vector4 :=
        Planets.Earth.Planet.Geodetic_To_ECEF (Latitude, Longitude, Altitude);

      use Matrices;
      use type Quaternions.Quaternion;

      Q_Lat_Lon : constant Quaternions.Quaternion :=
        Quaternions.Normalize
          (Quaternions.R (Init_Lon_Position, Position) *
           Quaternions.R (Init_Position, Init_Lon_Position));
   begin
      Subject.FDM.Set_Mass (Mass);
      Subject.FDM.Set_Gravity (Gravity);
      Subject.FDM.Set_Thrust (Thrust);

      Subject.Int.Initialize
        (Subject.FDM,
         Position => Position,
         Velocity => Matrices.R (Matrices.Vector4 (Q_Lat_Lon)) * Velocity,
         Orientation => Q_Lat_Lon *
           Q_Yaw (Yaw) * Q_Pitch (Pitch) * Q_Roll (Roll));
   end Reset;

   --  Compute initial velocity of Object_01 such that it will make perfect circular orbits
   Object_1_H : constant GL.Types.Double := 200_000.0;
   Object_1_A : constant GL.Types.Double := Planets.Earth.Planet.Semi_Major_Axis + Object_1_H;
   Object_1_V : constant GL.Types.Double := EF.Sqrt (Gravity_Earth * Object_1_A);
begin
   Ada.Text_IO.Put_Line ("v = " & Object_1_V'Image & " m/s");
   Ada.Text_IO.Put_Line ("v = " & GL.Types.Double'Image (Object_1_V * 3.6) & " km/h");

   --  Yaw: left
   --  Pitch: up
   --  Roll: right

   Reset (Object_01, Latitude => 0.0, Longitude => 0.0, Altitude => Object_1_H,
     Yaw => 0.0, Pitch => -90.0, Roll => 0.0,
     Velocity => (0.0, 0.0, Object_1_V, 0.0),
     Mass     => 9000.0,
     Thrust   => 0.0,
     Gravity  => Gravity_Earth);

   Reset (Object_02, Latitude => 20.0, Longitude => 90.0, Altitude => 0.0,
     Yaw => 90.0, Pitch => -90.0, Roll => 0.0,
     Velocity => (0.0, 0.0, 0.0, 0.0),
     Mass     => 1_000_000.0,
     Thrust   => 0.0,
     Gravity  => 0.0);

   Reset (Object_03, Latitude => 45.0, Longitude => -180.0, Altitude => 0.0,
     Yaw => 45.0, Pitch => -90.0, Roll => 0.0,
     Velocity => (0.0, 0.0, 0.0, 0.0),
     Mass     => 1_000_000.0,
     Thrust   => 0.0,
     Gravity  => 0.0);

end Atmosphere_Types.Objects;
