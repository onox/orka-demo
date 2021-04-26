with Orka.Transforms.Doubles.Matrices;

package Planets is
   pragma Pure;

   AU : constant := 149_597_870_700.0;

   type Planet_Characteristics is tagged record
      Axial_Tilt_Deg  : Orka.Float_64;
      Mass_Kg         : Orka.Float_64;
      Sidereal        : Duration;
      Flattening      : Orka.Float_64;
      Semi_Major_Axis : Orka.Float_64;
   end record;
   --  Axial tilt (deg) and rotation (hours) of planets in solar system at [1]
   --
   --  [1] https://en.wikipedia.org/wiki/Axial_tilt#Solar_System_bodies

   use type Orka.Float_64;

   function Semi_Minor_Axis (Object : Planet_Characteristics) return Orka.Float_64 is
     (Object.Semi_Major_Axis * (1.0 - Object.Flattening));

   function To_Duration (Hours, Minutes, Seconds : Orka.Float_64) return Duration is
     (Duration (Hours) * 3600.0 + Duration (Minutes) * 60.0 + Duration (Seconds));

   package Matrices renames Orka.Transforms.Doubles.Matrices;

   function Flattened_Vector
     (Planet    : Planet_Characteristics;
      Direction : Matrices.Vector4;
      Altitude  : Orka.Float_64) return Matrices.Vectors.Vector4;

   function Geodetic_To_ECEF
     (Planet                        : Planet_Characteristics;
      Latitude, Longitude, Altitude : Orka.Float_64) return Matrices.Vector4;
   --  Return a vector to the given geodetic position in ECEF coordinates
   --
   --  Latitude 0.0 deg (equator), longitude 0.0 deg (prime meridian), altitude 0 m
   --  gives a vector (<semi-major axis>, 0.0, 0.0, 1.0)

   function Radius
     (Planet              : Planet_Characteristics;
      Latitude, Longitude : Orka.Float_64) return Orka.Float_64;

   function Radius
     (Planet    : Planet_Characteristics;
      Direction : Matrices.Vector4) return Orka.Float_64;
--   with Pre => Matrices.Vectors.Normalized (Direction);

end Planets;
