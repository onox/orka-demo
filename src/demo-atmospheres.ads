with Orka.Features.Atmosphere.Earth;
with Orka.Features.Atmosphere.Rendering;
with Orka.Resources.Locations;
with Orka.Behaviors;
with Orka.Cameras;
with Orka.Rendering.Programs.Modules;

with Planets;

package Demo.Atmospheres is

   type Atmosphere is tagged limited private;

   function Create
     (Planet_Model         : aliased Orka.Features.Atmosphere.Model_Data;
      Planet_Data          : Planets.Planet_Characteristics;
      Location_Shaders     : Orka.Resources.Locations.Location_Ptr;
      Location_Precomputed : Orka.Resources.Locations.Writable_Location_Ptr) return Atmosphere;

   function Shader_Module (Object : Atmosphere)
     return Orka.Rendering.Programs.Modules.Module;

   procedure Render
     (Object : in out Atmosphere;
      Camera : Orka.Cameras.Camera_Ptr;
      Planet, Star : Orka.Behaviors.Behavior_Ptr);

private

   type Atmosphere is tagged limited record
      Program  : Orka.Features.Atmosphere.Rendering.Atmosphere;
      Textures : Orka.Features.Atmosphere.Precomputed_Textures;
   end record;

end Demo.Atmospheres;
