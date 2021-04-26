package Planets.Earth is
   pragma Preelaborate;

   --  Based on WGS 84. See https://en.wikipedia.org/wiki/World_Geodetic_System#WGS84
   Planet : constant Planet_Characteristics :=
     (Axial_Tilt_Deg  => 23.439_2811,
      Mass_Kg         => 5.972_37e24,
      Sidereal        => 23.0 * 3600.0 + 56.0 * 60.0 + 4.0905,
      Flattening      => 1.0 / 298.257_223_563,
      Semi_Major_Axis => 6_378_137.0);

end Planets.Earth;
