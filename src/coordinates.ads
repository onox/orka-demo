private with Ada.Numerics;

with GL.Types;

with Orka.Transforms.Doubles.Matrices;
with Orka.Transforms.Doubles.Quaternions;
with Orka.Transforms.Doubles.Vectors;

with Planets.Earth;

package Coordinates is

   package Quaternions renames Orka.Transforms.Doubles.Quaternions;
   package Vectors     renames Orka.Transforms.Doubles.Vectors;
   package Matrices    renames Orka.Transforms.Doubles.Matrices;

   GL_To_Geo       : constant Quaternions.Quaternion;
   Earth_Tilt      : constant Quaternions.Quaternion;

   Orientation_ECI : constant Quaternions.Quaternion;

   Rotate_ECI : constant Matrices.Matrix4;

   Inverse_Rotate_ECI : constant Matrices.Matrix4;

   function Rotate_ECEF return Matrices.Matrix4;

   Orientation_ECEF : Quaternions.Quaternion := Quaternions.Identity_Value;

private

   use type GL.Types.Double;

   GL_To_Geo : constant Quaternions.Quaternion :=
     Quaternions.R (Vectors.Normalize ((1.0, 1.0, 1.0, 0.0)),
       0.66667 * Ada.Numerics.Pi);

   Earth_Tilt : constant Quaternions.Quaternion :=
     Quaternions.R (Vectors.Normalize ((1.0, 0.0, 0.0, 0.0)),
       Vectors.To_Radians (Planets.Earth.Planet.Axial_Tilt_Deg));

   use type Quaternions.Quaternion;

   Orientation_ECI : constant Quaternions.Quaternion := Earth_Tilt * GL_To_Geo;

   Rotate_ECI : constant Matrices.Matrix4 :=
     Matrices.R (Matrices.Vector4 (Orientation_ECI));

   Inverse_Rotate_ECI : constant Matrices.Matrix4 :=
     Matrices.R (Matrices.Vector4 (Quaternions.Conjugate (Orientation_ECI)));

   function Rotate_ECEF return Matrices.Matrix4 is
     (Matrices.R (Matrices.Vector4 (Orientation_ECEF * Orientation_ECI)));

--   type Geocentric_Coordinate is record
--      X, Y, Z : GL.Types.Double;
--   end record;
   --  Geocentric coordinates or Earth-Centered Earth-Fixed (ECEF)
   --
   --  (0, 0, 0) is the center of mass of the Earth. The z-axis intersects
   --  the true north (north pole), while the x-axis intersects the Earth
   --  at 0 deg latitude and 0 deg longitude.

--   type Geodetic_Coordinate is record
--      Longitude, Latitude, Height : GL.Types.Double;
--   end record;

   --  Subsolar point (point when sun is directly above a position (at zenith):
   --
   --  latitude  = declination of the sun
   --  longitude = -15 * (T_UTC - 12 + E_min / 60) [2]
   --
   --  T_UTC = time UTC
   --  E_min = equation of time [1] in minutes
   --
   --  [1] https://en.wikipedia.org/wiki/Equation_of_time
   --  [2] https://doi.org/10.1016/j.renene.2021.03.047

end Coordinates;
