with Ada.Characters.Latin_1;
with Ada.Numerics;

with Orka.Rendering.Textures;
with Orka.Resources.Textures.KTX;
with Orka.Features.Terrain.Spheres;
with Orka.Transforms.Doubles.Matrices;
with Orka.Transforms.Doubles.Matrix_Conversions;
with Orka.Transforms.Doubles.Quaternions;
with Orka.Transforms.Doubles.Vectors;
with Orka.Transforms.Doubles.Vector_Conversions;

with GL.Types;

package body Demo.Terrains is

   Count : constant := 6;

   function Create_Terrain
     (Planet_Model       : aliased Orka.Features.Atmosphere.Model_Data;
      Planet_Data        : Planets.Planet_Characteristics;
      Atmosphere_Manager : Demo.Atmospheres.Atmosphere;
      Location_Data      : Orka.Resources.Locations.Location_Ptr;
      Location_Shaders   : Orka.Resources.Locations.Location_Ptr) return Terrain
   is
      use Orka.Rendering.Buffers;

      use type Orka.Float_64;
      use type GL.Types.Single_Array;

      Planet_Radius : constant Orka.Float_64 :=
        Planet_Data.Semi_Major_Axis / Planet_Model.Length_Unit_In_Meters;

      Terrain_Sphere_Side : constant Orka.Features.Terrain.Spheroid_Parameters :=
        Orka.Features.Terrain.Get_Spheroid_Parameters
          (Orka.Float_32 (Planet_Radius),
           Orka.Float_32 (Planet_Data.Flattening), True);

      Terrain_Sphere_Top : constant Orka.Features.Terrain.Spheroid_Parameters :=
        Orka.Features.Terrain.Get_Spheroid_Parameters
          (Orka.Float_32 (Planet_Radius),
           Orka.Float_32 (Planet_Data.Flattening), False);

      Terrain_Spheres : constant GL.Types.Single_Array :=
        Terrain_Sphere_Side &
        Terrain_Sphere_Side &
        Terrain_Sphere_Side &
        Terrain_Sphere_Side &
        Terrain_Sphere_Top &
        Terrain_Sphere_Top;

      -------------------------------------------------------------------------

      package MC renames Orka.Transforms.Doubles.Matrix_Conversions;
      package Quaternions renames Orka.Transforms.Doubles.Quaternions;

      Q_Rotate_90 : constant Quaternions.Quaternion :=
        Quaternions.R (Orka.Transforms.Doubles.Vectors.Normalize ((0.0, 0.0, 1.0, 0.0)),
        -2.0 * Ada.Numerics.Pi * 0.25);

      Q_Rotate_180 : constant Quaternions.Quaternion :=
        Quaternions.R (Orka.Transforms.Doubles.Vectors.Normalize ((0.0, 0.0, 1.0, 0.0)),
        -2.0 * Ada.Numerics.Pi * 0.50);

      Q_Rotate_270 : constant Quaternions.Quaternion :=
        Quaternions.R (Orka.Transforms.Doubles.Vectors.Normalize ((0.0, 0.0, 1.0, 0.0)),
        -2.0 * Ada.Numerics.Pi * 0.75);

      Q_Rotate_90_Up : constant Quaternions.Quaternion :=
        Quaternions.R (Orka.Transforms.Doubles.Vectors.Normalize ((0.0, 1.0, 0.0, 0.0)),
        2.0 * Ada.Numerics.Pi * 0.25);

      Q_Rotate_90_Down : constant Quaternions.Quaternion :=
        Quaternions.R (Orka.Transforms.Doubles.Vectors.Normalize ((0.0, 1.0, 0.0, 0.0)),
        -2.0 * Ada.Numerics.Pi * 0.25);

      package Matrices renames Orka.Transforms.Doubles.Matrices;

      Rotate_90 : constant Transforms.Matrix4 :=
        MC.Convert (Matrices.R (Matrices.Vector4 (Q_Rotate_90)));
      Rotate_180 : constant Transforms.Matrix4 :=
        MC.Convert (Matrices.R (Matrices.Vector4 (Q_Rotate_180)));
      Rotate_270 : constant Transforms.Matrix4 :=
        MC.Convert (Matrices.R (Matrices.Vector4 (Q_Rotate_270)));

      Rotate_90_Up : constant Transforms.Matrix4 :=
        MC.Convert (Matrices.R (Matrices.Vector4 (Q_Rotate_90_Up)));
      Rotate_90_Down : constant Transforms.Matrix4 :=
        MC.Convert (Matrices.R (Matrices.Vector4 (Q_Rotate_90_Down)));

      -------------------------------------------------------------------------

      DMap : constant GL.Objects.Textures.Texture :=
        Orka.Resources.Textures.KTX.Read_Texture (Location_Data, "terrain/texture4k-dmap.ktx");
      SMap : constant GL.Objects.Textures.Texture :=
        Orka.Resources.Textures.KTX.Read_Texture (Location_Data, "terrain/texture4k-smap.ktx");

      Terrain_GLSL : constant String
        := Orka.Resources.Convert (Orka.Resources.Byte_Array'(Location_Data.Read_Data
             ("terrain/terrain-render-atmosphere.frag").Get));

      use Ada.Characters.Latin_1;
      use Orka.Rendering.Programs;
      use Orka.Features.Atmosphere;

      Terrain_FS_Shader : constant String :=
        "#version 420" & LF &
        "#extension GL_ARB_shader_storage_buffer_object : require" & LF &
        (if Planet_Model.Luminance /= Orka.Features.Atmosphere.None then
           "#define USE_LUMINANCE" & LF
         else "") &
        "const float kLengthUnitInMeters = " &
          Planet_Model.Length_Unit_In_Meters'Image & ";" & LF &
        Terrain_GLSL & LF;

      Modules_Terrain_Render : constant Modules.Module_Array := Modules.Module_Array'
        (Atmosphere_Manager.Shader_Module,
         Modules.Create_Module_From_Sources (FS => Terrain_FS_Shader));
   begin
      return
        (Terrain_Transforms =>
          Create_Buffer
            ((Dynamic_Storage => True, others => False), Orka.Types.Single_Matrix_Type,
             Length => Count),
         Terrain_Sphere_Params =>
           Create_Buffer ((others => False), Terrain_Spheres),
         Terrain_Spheroid_Parameters => Terrain_Sphere_Side,

         Rotate_90      => Rotate_90,
         Rotate_180     => Rotate_180,
         Rotate_270     => Rotate_270,
         Rotate_90_Up   => Rotate_90_Up,
         Rotate_90_Down => Rotate_90_Down,

         Planet_Radius      => Planet_Radius,
         Planet_Unit_Length => Planet_Model.Length_Unit_In_Meters,

--         Program => Orka.Features.Terrain.Create_Terrain
--           (Count      => Count,
--            Min_Depth  => 6,
--            Max_Depth  => 20,
--            Scale      => 0.0,
--            Wireframe  => True,
--            Location   => Location_Shaders,
--            Render_Modules    => Modules_Terrain_Render,
--            Initialize_Render => null),
--            Initialize_Render => Initialize_Atmosphere_Terrain_Program'Access),
         Modules_Terrain_Render => Modules_Terrain_Render,
         DMap => DMap,
         SMap => SMap);
   end Create_Terrain;

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
      Timer_Render  : in out Orka.Timers.Timer)
   is
      procedure Update_Atmosphere_Terrain
        (Program : Orka.Rendering.Programs.Program)
      is
         use type Orka.Float_64;
         use Orka.Transforms.Doubles.Vectors;

         package VC renames Orka.Transforms.Doubles.Vector_Conversions;

         CP : constant Orka.Types.Singles.Vector4 :=
           VC.Convert (Camera.View_Position * (1.0 / Object.Planet_Unit_Length));

         Binding_Texture_SMap : constant := 5;
      begin
         Program.Uniform ("camera_pos").Set_Vector (CP);
         Program.Uniform ("earth_radius").Set_Single
           (GL.Types.Single (Object.Planet_Radius));

         Program.Uniform ("sun_direction").Set_Vector
           (Orka.Types.Singles.Vector4'(VC.Convert
              (Normalize (Star.Position - Planet.Position))));

         Orka.Rendering.Textures.Bind
           (Object.SMap,
            Orka.Rendering.Textures.Texture, Binding_Texture_SMap);
      end Update_Atmosphere_Terrain;

      use Transforms;

      Tile_Transforms : constant Orka.Types.Singles.Matrix4_Array :=
        (1 => Rotation,
         2 => Rotation * Object.Rotate_90,
         3 => Rotation * Object.Rotate_180,
         4 => Rotation * Object.Rotate_270,
         5 => Rotation * Object.Rotate_90_Up,
         6 => Rotation * Object.Rotate_90_Down);

      Sphere_Visibilities : constant GL.Types.Single_Array :=
        Orka.Features.Terrain.Spheres.Get_Sphere_Visibilities
          (Object.Terrain_Spheroid_Parameters,
           Tile_Transforms (1), Tile_Transforms (3), Center, Camera.View_Matrix);

      Visible_Buffers : constant Orka.Features.Terrain.Visible_Tile_Array :=
        Orka.Features.Terrain.Spheres.Get_Visible_Tiles (Sphere_Visibilities);
      pragma Assert (Visible_Buffers'Length = Terrain.Count);
   begin
      Visible_Tiles := 0;
      for Visible of Visible_Buffers loop
         if Visible then
            Visible_Tiles := Visible_Tiles + 1;
         end if;
      end loop;

      Object.Terrain_Transforms.Set_Data (Tile_Transforms);

      Terrain.Render
        (Transforms => Object.Terrain_Transforms,
         Spheres    => Object.Terrain_Sphere_Params,
         Center     => Center,
         Camera     => Camera,
         Parameters => Parameters,
         Visible_Tiles => Visible_Buffers,
         Update_Render => Update_Atmosphere_Terrain'Access,
         Height_Map => Object.DMap,
         Freeze     => Freeze,
         Wires      => Wires,
         Timer_Update => Timer_Update,
         Timer_Render => Timer_Render);
   end Render;

end Demo.Terrains;
