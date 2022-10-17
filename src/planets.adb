with Ada.Numerics.Generic_Elementary_Functions;

package body Planets is

   package EF is new Ada.Numerics.Generic_Elementary_Functions (Orka.Float_64);

   function Get_Vector
     (Latitude, Longitude : Orka.Float_64) return Matrices.Vectors.Vector4
   is
      Lon_Rad : constant Orka.Float_64 := Matrices.Vectors.To_Radians (Longitude);
      Lat_Rad : constant Orka.Float_64 := Matrices.Vectors.To_Radians (Latitude);

      XY : constant Orka.Float_64 := EF.Cos (Lat_Rad);

      X : constant Orka.Float_64 := XY * EF.Cos (Lon_Rad);
      Y : constant Orka.Float_64 := XY * EF.Sin (Lon_Rad);
      Z : constant Orka.Float_64 := EF.Sin (Lat_Rad);
   begin
      pragma Assert (Matrices.Vectors.Normalized ((X, Y, Z, 0.0)));
      return (X, Y, Z, 1.0);
   end Get_Vector;

   function Flattened_Vector
     (Planet    : Planet_Characteristics;
      Direction : Matrices.Vector4;
      Altitude  : Orka.Float_64) return Matrices.Vectors.Vector4
   is
      E2 : constant Orka.Float_64 := 2.0 * Planet.Flattening - Planet.Flattening**2;

      N : constant Orka.Float_64 := Planet.Semi_Major_Axis /
        EF.Sqrt (1.0 - E2 * Direction (Orka.Z)**2);
   begin
      return
        (Direction (Orka.X) * (N + Altitude),
         Direction (Orka.Y) * (N + Altitude),
         Direction (Orka.Z) * (N * (1.0 - E2) + Altitude),
         1.0);
   end Flattened_Vector;

   function Geodetic_To_ECEF
     (Planet                        : Planet_Characteristics;
      Latitude, Longitude, Altitude : Orka.Float_64) return Matrices.Vector4 is
   begin
      return Flattened_Vector (Planet, Get_Vector (Latitude, Longitude), Altitude);
   end Geodetic_To_ECEF;

   function Radius
     (Planet    : Planet_Characteristics;
      Direction : Matrices.Vector4) return Orka.Float_64 is
   begin
      return Matrices.Vectors.Norm (Flattened_Vector (Planet, Direction, 0.0));
   end Radius;

   function Radius
     (Planet    : Planet_Characteristics;
      Latitude, Longitude : Orka.Float_64) return Orka.Float_64 is
   begin
      return Radius (Planet, Get_Vector (Latitude, Longitude));
   end Radius;

end Planets;
