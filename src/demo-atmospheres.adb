with Ada.Text_IO;

with Orka.Features.Atmosphere.KTX;
with Orka.Transforms.Doubles.Matrices;

package body Demo.Atmospheres is

   package Matrices renames Orka.Transforms.Doubles.Matrices;

   function Create
     (Planet_Model         : aliased Orka.Features.Atmosphere.Model_Data;
      Planet_Data          : Planets.Planet_Characteristics;
      Location_Shaders     : Orka.Resources.Locations.Location_Ptr;
      Location_Precomputed : Orka.Resources.Locations.Writable_Location_Ptr) return Atmosphere
   is
      use Orka.Features.Atmosphere;
   begin
      if not Location_Precomputed.Exists ("irradiance.ktx") or
         not Location_Precomputed.Exists ("scattering.ktx") or
         not Location_Precomputed.Exists ("transmittance.ktx")
      then
         Ada.Text_IO.Put_Line ("Precomputing atmosphere. Stay a while and listen...");
         declare
            Atmosphere_Model : constant Model :=
              Create_Model (Planet_Model, Location_Shaders);
            Textures : constant Precomputed_Textures := Atmosphere_Model.Compute_Textures;
         begin
            Ada.Text_IO.Put_Line ("Precomputed textures for atmosphere");
            KTX.Save_Textures (Textures, Location_Precomputed);
            Ada.Text_IO.Put_Line ("Saved textures for atmosphere");
         end;
      end if;

      return
       (Program => Rendering.Create_Atmosphere
        (Planet_Model, Location_Shaders,
           Parameters => (Semi_Major_Axis => Planet_Data.Semi_Major_Axis,
                          Flattening      => Planet_Data.Flattening,
                          Axial_Tilt      => Matrices.Vectors.To_Radians
                                              (Planet_Data.Axial_Tilt_Deg),
                          Star_Radius     => <>)),
        Textures =>
          Orka.Features.Atmosphere.KTX.Load_Textures
            (Planet_Model, Orka.Resources.Locations.Location_Ptr (Location_Precomputed)));
   end Create;

   function Shader_Module (Object : Atmosphere)
     return Orka.Rendering.Programs.Modules.Module
   is (Object.Program.Shader_Module);

   procedure Render
     (Object : in out Atmosphere;
      Camera : Orka.Cameras.Camera_Ptr;
      Planet, Star : Orka.Behaviors.Behavior_Ptr) is
   begin
      Orka.Features.Atmosphere.Bind_Textures (Object.Textures);
      Object.Program.Render (Camera, Planet, Star);
   end Render;

end Demo.Atmospheres;
