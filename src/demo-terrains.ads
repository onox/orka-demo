with Orka.Behaviors;
with Orka.Cameras;
with Orka.Features.Atmosphere;
with Orka.Resources.Locations;
with Orka.Timers;
with Orka.Types;

with Orka.Rendering.Buffers;
with Orka.Rendering.Programs.Modules;
with Orka.Features.Terrain;

with GL.Objects.Textures;
with GL.Low_Level.Enums;

with Demo.Atmospheres;
with Planets;

package Demo.Terrains is

   type Terrain is tagged limited private;

   function Height_Map (Object : Terrain) return GL.Objects.Textures.Texture;
   function Slope_Map  (Object : Terrain) return GL.Objects.Textures.Texture;

   function Render_Modules (Object : Terrain) return Orka.Rendering.Programs.Modules.Module_Array;

   function Create_Terrain
     (Planet_Model       : aliased Orka.Features.Atmosphere.Model_Data;
      Planet_Data        : Planets.Planet_Characteristics;
      Atmosphere_Manager : Demo.Atmospheres.Atmosphere;
      Location_Data      : Orka.Resources.Locations.Location_Ptr;
      Location_Shaders   : Orka.Resources.Locations.Location_Ptr) return Terrain;

   procedure Render
     (Object        : in out Terrain;
      Terrain       : in out Orka.Features.Terrain.Terrain;
      Parameters    : Orka.Features.Terrain.Subdivision_Parameters;
      Visible_Tiles : out Natural;
      Camera        : Orka.Cameras.Camera_Ptr;
      Planet, Star  : Orka.Behaviors.Behavior_Ptr;
      Rotation      : Orka.Types.Singles.Matrix4;
      Center        : Orka.Cameras.Transforms.Matrix4;
      Freeze        : Boolean;
      Wires         : Boolean;
      Timer_Update  : in out Orka.Timers.Timer;
      Timer_Render  : in out Orka.Timers.Timer);

private

   use Orka.Cameras;

   package LE renames GL.Low_Level.Enums;

   type Terrain is tagged limited record
--      Program : Orka.Features.Terrain.Terrain (Count => 6);

      Terrain_Transforms    : Orka.Rendering.Buffers.Buffer (Orka.Types.Single_Matrix_Type);
      Terrain_Sphere_Params : Orka.Rendering.Buffers.Buffer (Orka.Types.Single_Type);

      Terrain_Spheroid_Parameters : Orka.Features.Terrain.Spheroid_Parameters;

      Modules_Terrain_Render : Orka.Rendering.Programs.Modules.Module_Array (1 .. 2);

      Rotate_90      : Transforms.Matrix4;
      Rotate_180     : Transforms.Matrix4;
      Rotate_270     : Transforms.Matrix4;
      Rotate_90_Up   : Transforms.Matrix4;
      Rotate_90_Down : Transforms.Matrix4;

      Planet_Radius      : Orka.Float_64;
      Planet_Unit_Length : Orka.Float_64;

      DMap : GL.Objects.Textures.Texture (LE.Texture_2D);
      SMap : GL.Objects.Textures.Texture (LE.Texture_2D);
   end record;

   function Render_Modules (Object : Terrain) return Orka.Rendering.Programs.Modules.Module_Array
     is (Object.Modules_Terrain_Render);

   function Height_Map (Object : Terrain) return GL.Objects.Textures.Texture is (Object.DMap);
   function Slope_Map  (Object : Terrain) return GL.Objects.Textures.Texture is (Object.SMap);

end Demo.Terrains;
