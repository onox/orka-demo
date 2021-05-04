with Ada.Exceptions;
with Ada.Numerics.Generic_Elementary_Functions;
with Ada.Real_Time;
with Ada.Text_IO;

with GL.Buffers;
with GL.Low_Level.Enums;
with GL.Objects.Textures;
with GL.Pixels;
with GL.Toggles;
with GL.Types;

with Orka.Behaviors;
with Orka.Cameras.Rotate_Around_Cameras;
with Orka.Contexts.AWT;
with Orka.Debug;
with Orka.Features.Atmosphere.Earth;
with Orka.Features.Terrain.Spheres;
with Orka.Inputs.Joysticks.Filtering;
with Orka.Inputs.Joysticks.Gamepads;
with Orka.Inputs.Pointers;
with Orka.Loggers.Terminal;
with Orka.Logging;
with Orka.Loops;
with Orka.Rendering.Buffers;
with Orka.Rendering.Drawing;
with Orka.Rendering.Debug.Bounding_Boxes;
with Orka.Rendering.Debug.Coordinate_Axes;
with Orka.Rendering.Debug.Lines;
with Orka.Rendering.Debug.Spheres;
with Orka.Rendering.Effects.Filters;
with Orka.Rendering.Framebuffers;
with Orka.Rendering.Programs.Modules;
with Orka.Rendering.Programs.Uniforms;
with Orka.Rendering.Textures;
with Orka.Resources.Locations.Directories;
with Orka.Timers;
with Orka.Transforms.Doubles.Quaternions;
with Orka.Transforms.Singles.Matrices;
with Orka.Transforms.Singles.Vectors;
with Orka.Transforms.Doubles.Matrices;
with Orka.Transforms.Doubles.Matrix_Conversions;
with Orka.Transforms.Doubles.Vectors;
with Orka.Transforms.Doubles.Vector_Conversions;
with Orka.Types;
with Orka.Windows;
with AWT.Inputs;

with Atmosphere_Types.Objects;
with Coordinates;
with Planets.Earth;
with Demo.Atmospheres;
with Demo.Terrains;

procedure Orka_Demo is
   Window_Width   : constant := 1280;
   Window_Height  : constant := 720;

   Width   : constant := 1280;
   Height  : constant := 720;
   Samples : constant := 1;

   --  Degrees per cell for the white debug grid
   Deg_Per_Cell : constant := 3;

   Earth_Rotation_Speedup : constant := 1;
   --  Camera system rotates around Sphere if speed up is large (>= 1000) :/

   Terrain_Parameters : Orka.Features.Terrain.Subdivision_Parameters :=
     (Meshlet_Subdivision  => 3,
      Edge_Length_Target   => 16,
      Min_LoD_Standard_Dev => 0.00);

   Displace_Terrain : constant Boolean := False;
   --  To show displaced terrain:
   --
   --  1. Set Displace_Terrain to True
   --  2. Set Terrain_Parameters to (1, 16, 1.0)
   --  3. Multiply z * 1000.0 in function planeToSphere in
   --     ../orka/orka_plugin_terrain/data/shaders/terrain/terrain-render-sphere.glsl

   Terrain_Min_Depth : constant := 6;
   Terrain_Max_Depth : constant := 20;

   type View_Object_Kind is (Sphere_Kind, Planet_Kind, Satellite_Kind);

   Previous_Viewed_Object, Current_Viewed_Object : View_Object_Kind := Sphere_Kind;

   View_Azimuth_Angle_Radians : constant := 0.0 * Ada.Numerics.Pi;
   View_Zenith_Angle_Radians  : constant := 0.1 * Ada.Numerics.Pi;

   View_Object_Distance : constant := (if Displace_Terrain then 2500_000.0 else 20_000.0);

   type Blur_Kind is (None, Moving_Average, Gaussian);
   type Blur_Kernel is (Small, Medium, Large, Very_Large);

   Freeze_Terrain_Update   : Boolean     := False;
   Show_Terrain_Wireframe  : Boolean     := True;
   Do_Blur                 : Blur_Kind   := None;
   Blur_Kernel_Size        : Blur_Kernel := Small;
   Use_Smap                : Boolean     := True;

   Do_White_Balance        : constant Boolean := True;
   Show_White_Grid         : constant Boolean := False;
   Show_Stationary_Targets : constant Boolean := True;
   Show_Satellites         : constant Boolean := True;
   Render_Terrain          : constant Boolean := True;
   Render_Debug_Geometry   : constant Boolean := True;

   Visible_Tiles           : Natural := 0;

   Min_AU : constant := 0.005;

   Planet_Rotations     : GL.Types.Double := 0.0;
   Height_Above_Surface : GL.Types.Double := 0.0;

   Step_Y : GL.Types.Int := 0;

   Exposure : GL.Types.Single := 10.0;

   function Clamp (Value : GL.Types.Int) return GL.Types.Int is
     (GL.Types.Int'Max (0, GL.Types.Int'Min (Value, 20)));

   package EF is new Ada.Numerics.Generic_Elementary_Functions (GL.Types.Double);
   package Matrices    renames Orka.Transforms.Doubles.Matrices;
   package Quaternions renames Orka.Transforms.Doubles.Quaternions;

   package LE renames GL.Low_Level.Enums;
   package MC renames Orka.Transforms.Doubles.Matrix_Conversions;
   package GP renames Orka.Inputs.Joysticks.Gamepads;
   package Filtering renames Orka.Inputs.Joysticks.Filtering;

   package BBoxes  renames Orka.Rendering.Debug.Bounding_Boxes;
   package Lines   renames Orka.Rendering.Debug.Lines;
   package Axes    renames Orka.Rendering.Debug.Coordinate_Axes;
   package Spheres renames Orka.Rendering.Debug.Spheres;

   function Image_D (Value : GL.Types.Double) return String is
      package Double_IO is new Ada.Text_IO.Float_IO (GL.Types.Double);

      Value_String : String := "123456789012.12";
   begin
      Double_IO.Put (Value_String, Value, Aft => 2, Exp => 0);
      return Orka.Logging.Trim (Value_String);
   end Image_D;

   function Get_White_Points
     (Planet : aliased Orka.Features.Atmosphere.Model_Data) return GL.Types.Single_Array
   is
      use type Orka.Float_64;

      R, G, B : Orka.Float_64 := 1.0;
   begin
      Orka.Features.Atmosphere.Convert_Spectrum_To_Linear_SRGB (Planet, R, G, B);

      declare
         White_Point : constant Orka.Float_64 := (R + G + B) / 3.0;
      begin
         return
          (Orka.Float_32 (R / White_Point),
           Orka.Float_32 (G / White_Point),
           Orka.Float_32 (B / White_Point));
      end;
   end Get_White_Points;

   use Ada.Real_Time;

   T1 : constant Time := Clock;

   Context : constant Orka.Contexts.Surface_Context'Class :=
     Orka.Contexts.AWT.Create_Context
       (Version => (4, 2),
        Flags   => (Debug => True, others => False));

   Window : aliased Orka.Windows.Window'Class := Demo.Create_Window
     (Context, Window_Width, Window_Height, Resizable => False);

   use Orka.Resources;
   use type GL.Types.Double;

   Location_Data : constant Locations.Location_Ptr
     := Locations.Directories.Create_Location ("data");

   Location_Orka_Shaders : constant Locations.Location_Ptr
     := Locations.Directories.Create_Location ("../orka/orka/data/shaders");

   Location_Atmosphere_Shaders : constant Locations.Location_Ptr
     := Locations.Directories.Create_Location ("../orka/orka_plugin_atmosphere/data/shaders");

   Location_Terrain_Shaders : constant Locations.Location_Ptr
     := Locations.Directories.Create_Location ("../orka/orka_plugin_terrain/data/shaders");

   Location_Precomputed : constant Locations.Writable_Location_Ptr
     := Locations.Directories.Create_Location ("results");

   -----------------------------------------------------------------------------

   JS : Orka.Inputs.Joysticks.Joystick_Input_Access;

   --  FIXME
--   JS_Manager : constant Orka.Inputs.Joysticks.Joystick_Manager_Ptr :=
--     Orka.Inputs.GLFW.Create_Joystick_Manager;

   use type GL.Types.Single;
   use type Orka.Inputs.Joysticks.Joystick_Input_Access;
begin
   Orka.Logging.Set_Logger (Orka.Loggers.Terminal.Create_Logger (Level => Orka.Loggers.Debug));
   Orka.Debug.Set_Log_Messages (Enable => True, Raise_API_Error => True);
   Ada.Text_IO.Put_Line ("Context version: " & Orka.Contexts.Image (Context.Version));

   Context.Enable (Orka.Contexts.Reversed_Z);
   pragma Assert (Samples > 0);
   Context.Enable (Orka.Contexts.Multisample);

   declare
      Mappings : constant String
        := Convert (Orka.Resources.Byte_Array'(Location_Data.Read_Data
             ("gamecontrollerdb.txt").Get));
   begin
      --  FIXME
      null;
--      Glfw.Input.Joysticks.Update_Gamepad_Mappings (Mappings);
   end;

--   JS_Manager.Acquire (JS);

   if JS /= null then
      Ada.Text_IO.Put_Line ("Joystick:");
      Ada.Text_IO.Put_Line ("  Name: " & JS.Name);
      Ada.Text_IO.Put_Line ("  GUID: " & JS.GUID);
      Ada.Text_IO.Put_Line ("  Present: " & JS.Is_Present'Image);
      Ada.Text_IO.Put_Line ("  Gamepad: " & JS.Is_Gamepad'Image);
   else
      Ada.Text_IO.Put_Line ("No joystick present");
   end if;

--   if JS = null then
--      JS := Orka.Inputs.Joysticks.Default.Create_Joystick_Input (Window.Pointer_Input,
--        (0.01, 0.01, 0.01, 0.01));
--   end if;

   declare
      use Orka.Features.Atmosphere;
      use Orka.Features.Terrain;

      Earth : aliased constant Model_Data :=
        Orka.Features.Atmosphere.Earth.Data (Luminance => None);

      Atmosphere_Manager : Demo.Atmospheres.Atmosphere :=
        Demo.Atmospheres.Create
          (Earth, Planets.Earth.Planet, Location_Atmosphere_Shaders, Location_Precomputed);

      --------------------------------------------------------------------------

      Terrain_Manager_Helper : Demo.Terrains.Terrain :=
        Demo.Terrains.Create_Terrain (Earth, Planets.Earth.Planet,
          Atmosphere_Manager, Location_Data, Location_Terrain_Shaders);

      Uniform_Smap : Orka.Rendering.Programs.Uniforms.Uniform (LE.Bool_Type);

      procedure Initialize_Atmosphere_Terrain_Program
        (Program : Orka.Rendering.Programs.Program) is
      begin
         Program.Uniform_Sampler ("u_DmapSampler").Verify_Compatibility
           (Terrain_Manager_Helper.Height_Map);
         Program.Uniform_Sampler ("u_SmapSampler").Verify_Compatibility
           (Terrain_Manager_Helper.Slope_Map);
         Uniform_Smap := Program.Uniform ("u_UseSmap");
      end Initialize_Atmosphere_Terrain_Program;

      Terrain_Manager : Orka.Features.Terrain.Terrain := Create_Terrain
        (Count      => 6,
         Min_Depth  => Terrain_Min_Depth,
         Max_Depth  => Terrain_Max_Depth,
         Scale      => (if Displace_Terrain then 1.0 else 0.0),
         Wireframe  => True,
         Location   => Location_Terrain_Shaders,
         Render_Modules    => Terrain_Manager_Helper.Render_Modules,
         Initialize_Render => Initialize_Atmosphere_Terrain_Program'Access);

      --------------------------------------------------------------------------

      Timer_0, Timer_1, Timer_2, Timer_3, Timer_4 : Orka.Timers.Timer := Orka.Timers.Create_Timer;

      type Timer_Array is array (Positive range 1 .. 4) of Duration;

      Timer_Terrain_Update : Orka.Timers.Timer := Orka.Timers.Create_Timer;
      Timer_Terrain_Render : Orka.Timers.Timer := Orka.Timers.Create_Timer;

      New_Terrain_Timers : Timer_Array := (others => 0.0);
      Terrain_Timers     : Timer_Array := (others => 0.0);
      GPU_Timers         : Timer_Array := (others => 0.0);

      use GL.Objects.Textures;
      use type GL.Types.Int;

      Texture_1 : Texture (if Samples > 0 then LE.Texture_2D_Multisample else LE.Texture_2D);
      Texture_2 : Texture (if Samples > 0 then LE.Texture_2D_Multisample else LE.Texture_2D);
      Texture_3 : Texture (LE.Texture_Rectangle);
      Texture_4 : Texture (LE.Texture_Rectangle);
   begin
      Texture_3.Allocate_Storage (1, 0, GL.Pixels.RGBA8, Width, Height, 1);
      Texture_4.Allocate_Storage (1, 0, GL.Pixels.RGBA8, Width / 2, Height / 2, 1);

      declare
         use Orka.Rendering.Framebuffers;
         use Orka.Rendering.Buffers;
         use Orka.Rendering.Programs;
         use Orka.Rendering.Effects.Filters;

         P_2 : Program := Create_Program (Modules.Module_Array'
           (Modules.Create_Module (Location_Orka_Shaders, VS => "oversized-triangle.vert"),
            Modules.Create_Module (Location_Data, FS => "demo/resolve.frag")));

         FB_1 : Framebuffer := Create_Framebuffer (Width, Height, Samples, Context);
         FB_3 : Framebuffer := Create_Framebuffer (Width, Height, 0, Context);
         FB_4 : Framebuffer := Create_Framebuffer (Width / 2, Height / 2, 0, Context);

         FB_D : Framebuffer (Default => True);

         Blur_Filter_GK : array (Blur_Kernel) of Separable_Filter :=
           (Small => Create_Filter
              (Location_Orka_Shaders, Texture_4, Kernel => Gaussian_Kernel (Radius => 6)),
            Medium => Create_Filter
              (Location_Orka_Shaders, Texture_4, Kernel => Gaussian_Kernel (Radius => 24)),
            Large => Create_Filter
              (Location_Orka_Shaders, Texture_4, Kernel => Gaussian_Kernel (Radius => 48)),
            Very_Large => Create_Filter
              (Location_Orka_Shaders, Texture_4, Kernel => Gaussian_Kernel (Radius => 96)));

         Blur_Filter_MA : array (Blur_Kernel) of Moving_Average_Filter :=
           (Small => Create_Filter
              (Location_Orka_Shaders, Texture_4, Radius => 1),
            Medium => Create_Filter
              (Location_Orka_Shaders, Texture_4, Radius => 4),
            Large => Create_Filter
              (Location_Orka_Shaders, Texture_4, Radius => 8),
            Very_Large => Create_Filter
              (Location_Orka_Shaders, Texture_4, Radius => 16));

         use Orka.Cameras;
         Lens : constant Lens_Ptr
           := new Camera_Lens'Class'(Create_Lens
                (Width, Height, Transforms.FOV (36.0, 50.0), Context));

         Current_Camera : constant Camera_Ptr
           := new Camera'Class'(Camera'Class
                (Rotate_Around_Cameras.Create_Camera (Window.Pointer_Input, Lens)));

         -----------------------------------------------------------------------

         use Orka.Transforms.Doubles.Matrices;

         Sphere : constant Orka.Behaviors.Behavior_Ptr := new Atmosphere_Types.No_Behavior'
           (Position => (0.0, 0.0, 0.0, 1.0));

         Planet : constant Orka.Behaviors.Behavior_Ptr := new Atmosphere_Types.No_Behavior'
           (Position => (0.0, 0.0, 0.0, 1.0));

         Sun : constant Orka.Behaviors.Behavior_Ptr := new Atmosphere_Types.No_Behavior'
           (Position => (0.0, 0.0, Planets.AU, 1.0));

         use Atmosphere_Types.Objects;

         White_Points : constant GL.Types.Single_Array := Get_White_Points (Earth);

         procedure Update_Viewed_Object (Camera : Camera_Ptr; Kind : View_Object_Kind) is
            Object : constant Orka.Behaviors.Behavior_Ptr :=
              (case Current_Viewed_Object is
                 when Sphere_Kind    => Sphere,
                 when Planet_Kind    => Planet,
                 when Satellite_Kind => Object_01);
            --  Object_01: satellite
            --  Object_02: position on surface showing atmosphere problem near surface
            --    due to flattening of the Earth (atmosphere assumes sphere is not flattened)
            --  Object_03: position on surface on the edge of two adjacent terrain tiles
         begin
            if Camera.all in Observing_Camera'Class then
               Observing_Camera'Class (Camera.all).Look_At (Object);
            elsif Camera.all in First_Person_Camera'Class then
               First_Person_Camera'Class (Camera.all).Set_Position (Object.Position);
            end if;

            if Camera.all in Rotate_Around_Cameras.Rotate_Around_Camera'Class then
               Rotate_Around_Cameras.Rotate_Around_Camera'Class
                 (Camera.all).Set_Radius
                    (case Current_Viewed_Object is
                       when Sphere_Kind | Satellite_Kind => View_Object_Distance,
                       when Planet_Kind                  => 20_000_000.0);
            end if;

            Previous_Viewed_Object := Current_Viewed_Object;
         end Update_Viewed_Object;
      begin
         FB_1.Set_Default_Values
           ((Color => (0.0, 0.0, 0.0, 1.0),
             Depth => (if Context.Enabled (Orka.Contexts.Reversed_Z) then 0.0 else 1.0),
             others => <>));

--         Texture_1.Allocate_Storage (1, Samples, GL.Pixels.RGBA16F, Width, Height, 1);
         Texture_1.Allocate_Storage (1, Samples, GL.Pixels.R11F_G11F_B10F, Width, Height, 1);
         Texture_2.Allocate_Storage (1, Samples, GL.Pixels.Depth_Component32F, Width, Height, 1);

         FB_1.Attach (Texture_1);
         FB_1.Attach (Texture_2);

         FB_3.Attach (Texture_3);
         FB_4.Attach (Texture_4);

         if Current_Camera.all in Rotate_Around_Cameras.Rotate_Around_Camera'Class then
            Rotate_Around_Cameras.Rotate_Around_Camera'Class
              (Current_Camera.all).Set_Angles
                 (View_Azimuth_Angle_Radians, View_Zenith_Angle_Radians);
         end if;

         Update_Viewed_Object (Current_Camera, Current_Viewed_Object);

         Current_Camera.Set_Input_Scale (0.002, 0.002, 50_000.0);

         GL.Toggles.Enable (GL.Toggles.Depth_Test);
         GL.Toggles.Enable (GL.Toggles.Cull_Face);

         declare
            Current_Time : Time := Clock - Microseconds (16_667);

            Start_Time : constant Time := Clock;
            Prev_Time : Time := Start_Time;

            BBox : BBoxes.Bounding_Box  := BBoxes.Create_Bounding_Box (Location_Orka_Shaders);
            Line : Lines.Line           := Lines.Create_Line (Location_Orka_Shaders);
            Axis : Axes.Coordinate_Axes := Axes.Create_Coordinate_Axes (Location_Orka_Shaders);

            Debug_Sphere : Spheres.Sphere := Spheres.Create_Sphere
              (Location_Orka_Shaders, Color => (1.0, 1.0, 1.0, 0.5),
--               Cells_Horizontal => 24 * 60,  -- 1 min/cell
               Cells_Horizontal => 36 * 10 / Deg_Per_Cell,
               Cells_Vertical   => 18 * 10 / Deg_Per_Cell);

            Mutable_Buffer_Flags : constant Orka.Rendering.Buffers.Storage_Bits :=
              (Dynamic_Storage => True, others => False);

            BBox_Transforms : constant Buffer := Create_Buffer
              (Mutable_Buffer_Flags, Orka.Types.Single_Matrix_Type, 3);
            BBox_Bounds     : constant Buffer := Create_Buffer
              (Mutable_Buffer_Flags, Orka.Types.Single_Vector_Type, 6);

            Axes_Transforms : constant Buffer := Create_Buffer
              (Mutable_Buffer_Flags, Orka.Types.Single_Matrix_Type, 2);
            Axes_Sizes      : constant Buffer := Create_Buffer
              (Mutable_Buffer_Flags, Orka.Types.Single_Type, 1);

            S_S_A : constant GL.Types.Single_Array :=
              (Orka.Float_32 (Planets.Earth.Planet.Semi_Major_Axis / Earth.Length_Unit_In_Meters),
               Orka.Float_32 (Planets.Earth.Planet.Flattening));

            Sphere_Params_A : constant Buffer := Create_Buffer ((others => False), S_S_A);

            Sphere_Transforms_A : constant Buffer := Create_Buffer
              (Mutable_Buffer_Flags, Orka.Types.Single_Matrix_Type,
               Sphere_Params_A.Length / 2);

            Line_Transforms_ECI  : constant Buffer := Create_Buffer
              (Mutable_Buffer_Flags, Orka.Types.Single_Matrix_Type, 1);
            Line_Transforms_ECEF : constant Buffer := Create_Buffer
              (Mutable_Buffer_Flags, Orka.Types.Single_Matrix_Type, 1);
            Line_Colors     : constant Buffer := Create_Buffer
              (Mutable_Buffer_Flags, Orka.Types.Single_Vector_Type, 1);

            Line_Points_ECI  : constant Buffer := Create_Buffer
              (Mutable_Buffer_Flags, Orka.Types.Single_Vector_Type, 4);
            Line_Points_ECEF : constant Buffer := Create_Buffer
              (Mutable_Buffer_Flags, Orka.Types.Single_Vector_Type, 16);

            package Loops is new Orka.Loops
              (Time_Step   => Ada.Real_Time.Microseconds (2_083),
               Frame_Limit => Ada.Real_Time.Microseconds (16_667),
               Camera      => Current_Camera,
               Job_Manager => Demo.Job_System);

            procedure Render_Scene
              (Scene  : not null Orka.Behaviors.Behavior_Array_Access;
               Camera : Orka.Cameras.Camera_Ptr)
            is
               P_I : Orka.Inputs.Pointers.Pointer_Input_Ptr renames Window.Pointer_Input;

               use Orka.Transforms.Doubles.Vectors;
               use Orka.Transforms.Doubles.Vector_Conversions;
               use type Quaternions.Quaternion;
               use Orka.Cameras.Transforms;

               Earth_Rotation : constant Quaternions.Quaternion :=
                 Quaternions.R (Orka.Transforms.Doubles.Vectors.Normalize ((0.0, 0.0, 1.0, 0.0)),
                   -2.0 * Ada.Numerics.Pi * (Planet_Rotations + GL.Types.Double
                     (To_Duration (Clock - Start_Time) /
                       (Planets.Earth.Planet.Sidereal / Earth_Rotation_Speedup))));

               Orientation_ECI : constant Transforms.Matrix4 :=
                 MC.Convert (Matrices.R (Matrices.Vector4
                   (Coordinates.Orientation_ECI)));

               Orientation_ECEF : constant Transforms.Matrix4 :=
                 MC.Convert (Matrices.R (Matrices.Vector4
                   (Earth_Rotation * Coordinates.Orientation_ECI)));

               function Translate_To (Object : Orka.Behaviors.Behavior_Ptr)
                 return Transforms.Matrix4
               is
                  Camera_To_Object : constant Transforms.Vector4 :=
                    Convert ((Object.Position - Camera.View_Position)
                      * (1.0 / Earth.Length_Unit_In_Meters));
               begin
                  return T (Camera_To_Object);
               end Translate_To;

               Move_To_Earth_Center  : constant Transforms.Matrix4 := Translate_To (Planet);
               Move_To_Sphere_Center : constant Transforms.Matrix4 := Translate_To (Sphere);
               Move_To_Satellite_Center : constant Transforms.Matrix4 := Translate_To (Object_01);

               New_Time : constant Time     := Clock;
               DT       : constant Duration := To_Duration (New_Time - Current_Time);

               Alpha : constant Orka.Float_32 := (if Window.State.Transparent then 0.5 else 1.0);
               use all type Orka.Logging.Severity;
            begin
               if Window.Resize then
                  Window.Resize := False;

                  FB_D := Orka.Rendering.Framebuffers.Get_Default_Framebuffer (Window);
                  FB_D.Set_Default_Values ((Color => (0.0, 0.0, 0.0, Alpha), others => <>));
                  Demo.Messages.Log (Debug, "FB default window, new size: " &
                    Window.Width'Image & Window.Height'Image);
               end if;

               FB_D.Clear ((Color => True, others => False));

               Timer_0.Start;
               Coordinates.Orientation_ECEF := Earth_Rotation;

               Atmosphere_Types.No_Behavior (Sphere.all).Position := Coordinates.Rotate_ECEF *
                 Planets.Earth.Planet.Geodetic_To_ECEF
                   (Latitude => 0.0, Longitude => 0.0, Altitude => 1_000.0);

               Current_Time := New_Time;

               if Current_Time - Prev_Time > Seconds (2) then
                  Prev_Time := Current_Time;
                  Terrain_Timers := (others => 0.0);
                  GPU_Timers     := (others => 0.0);
               end if;

               Camera.Set_Up_Direction (Matrices.Vectors.Normalize
                 (Observing_Camera'Class (Camera.all).Target_Position - Planet.Position));

               FB_1.Use_Framebuffer;
               FB_1.Clear ((Color | Depth => True, others => False));

               if JS /= null and then JS.Is_Present then
                  declare
                     Dead_Zones : constant array (1 .. 6) of Orka.Inputs.Joysticks.Axis_Position :=
                       (1 | 3  => 0.05,
                        2 | 4  => 0.03,
                        5 .. 6 => 0.0);

                     K_RC : constant GL.Types.Single := Filtering.RC (10.0);

                     Last_State : constant Orka.Inputs.Joysticks.Joystick_State := JS.Last_State;
                     --  TODO Shouldn't this be Current_State?

                     procedure Process_Axis
                       (Value : in out Orka.Inputs.Joysticks.Axis_Position;
                        Index :        Positive)
                     is
                        DZ : constant Orka.Inputs.Joysticks.Axis_Position := Dead_Zones (Index);
                     begin
                        Value := Filtering.Dead_Zone (Value, DZ);

                        Value := Filtering.Low_Pass_Filter
                         (Value, Last_State.Axes (Index),
                           K_RC, GL.Types.Single (DT));
                     end Process_Axis;
                  begin
                     JS.Update_State (Process_Axis'Access);
                  end;

                  declare
                     State : constant Orka.Inputs.Joysticks.Joystick_State := JS.Current_State;
                     Last_State : constant Orka.Inputs.Joysticks.Joystick_State := JS.Last_State;
                     use all type Orka.Inputs.Joysticks.Button_State;
                     use GP;

                     --  FIXME
                     subtype Gamepad_Button_Index is Positive range 1 .. 15;

                     function Value (Value : Gamepad_Button_Index) return GP.Button is
                       (GP.Button'Val (Value - Gamepad_Button_Index'First));
                  begin
                     for Index in 1 .. State.Button_Count loop
                        if State.Buttons (Index) /= Last_State.Buttons (Index) then
                           if Value (Index) = Right_Pad_Left
                             and State.Buttons (Index) = Pressed
                           then
                              Freeze_Terrain_Update := not Freeze_Terrain_Update;
                           end if;

                           if Value (Index) = Right_Pad_Right
                             and State.Buttons (Index) = Pressed
                           then
                              Do_Blur := (if Do_Blur /= Blur_Kind'Last then
                                            Blur_Kind'Succ (Do_Blur)
                                          else
                                            Blur_Kind'First);
                           end if;

                           if Value (Index) = Right_Pad_Up
                             and State.Buttons (Index) = Pressed
                           then
                              Show_Terrain_Wireframe := not Show_Terrain_Wireframe;
                           end if;

                           if Value (Index) = Right_Pad_Down
                             and State.Buttons (Index) = Pressed
                           then
                              Current_Viewed_Object :=
                                (if Current_Viewed_Object /= View_Object_Kind'Last then
                                   View_Object_Kind'Succ (Current_Viewed_Object)
                                 else
                                   View_Object_Kind'First);
                           end if;

                           if Value (Index) = Left_Pad_Up
                             and State.Buttons (Index) = Pressed
                             and State.Buttons (GP.Index (Center_Right)) = Pressed
                           then
                              Step_Y := Clamp (Step_Y - 1);
                           end if;

                           if Value (Index) = Left_Pad_Down
                             and State.Buttons (Index) = Pressed
                             and State.Buttons (GP.Index (Center_Right)) = Pressed
                           then
                              Step_Y := Clamp (Step_Y + 1);
                           end if;

                           if Value (Index) = Left_Pad_Up
                             and State.Buttons (Index) = Pressed
                             and State.Buttons (GP.Index (Center_Right)) = Released
                             and Terrain_Parameters.Meshlet_Subdivision
                                   < Orka.Features.Terrain.Meshlet_Subdivision_Depth'Last
                           then
                              Terrain_Parameters.Meshlet_Subdivision :=
                                 Terrain_Parameters.Meshlet_Subdivision + 1;
                           end if;

                           if Value (Index) = Left_Pad_Down
                             and State.Buttons (Index) = Pressed
                             and State.Buttons (GP.Index (Center_Right)) = Released
                             and Terrain_Parameters.Meshlet_Subdivision
                                   > Orka.Features.Terrain.Meshlet_Subdivision_Depth'First
                           then
                              Terrain_Parameters.Meshlet_Subdivision :=
                                 Terrain_Parameters.Meshlet_Subdivision - 1;
                           end if;

                           if Value (Index) = Left_Pad_Left
                             and State.Buttons (Index) = Pressed
                             and State.Buttons (GP.Index (Center_Right)) = Released
                             and Terrain_Parameters.Min_LoD_Standard_Dev
                                   <= 0.9
                           then
                              Terrain_Parameters.Min_LoD_Standard_Dev :=
                                 Terrain_Parameters.Min_LoD_Standard_Dev + 0.1;
                           end if;

                           if Value (Index) = Left_Pad_Right
                             and State.Buttons (Index) = Pressed
                             and State.Buttons (GP.Index (Center_Right)) = Released
                             and Terrain_Parameters.Min_LoD_Standard_Dev
                                   >= 0.1
                           then
                              Terrain_Parameters.Min_LoD_Standard_Dev :=
                                 Terrain_Parameters.Min_LoD_Standard_Dev - 0.1;
                           end if;

                           if Value (Index) = Left_Pad_Left
                             and State.Buttons (Index) = Pressed
                             and State.Buttons (GP.Index (Center_Right)) = Pressed
                             and Blur_Kernel_Size /= Blur_Kernel'First
                           then
                              Blur_Kernel_Size := Blur_Kernel'Pred (Blur_Kernel_Size);
                           end if;

                           if Value (Index) = Left_Pad_Right
                             and State.Buttons (Index) = Pressed
                             and State.Buttons (GP.Index (Center_Right)) = Pressed
                             and Blur_Kernel_Size /= Blur_Kernel'Last
                           then
                              Blur_Kernel_Size := Blur_Kernel'Succ (Blur_Kernel_Size);
                           end if;

                           if Value (Index) = Center_Left
                             and State.Buttons (Index) = Pressed
                           then
                              Use_Smap := not Use_Smap;
                              Uniform_Smap.Set_Boolean (Use_Smap);
                           end if;

                           if Value (Index) = Left_Shoulder
                             and State.Buttons (Index) = Pressed
                           then
                              Exposure := Exposure + 0.1;
                           end if;

                           if Value (Index) = Right_Shoulder
                             and State.Buttons (Index) = Pressed
                           then
                              Exposure := GL.Types.Single'Max (0.0, Exposure - 0.1);
                           end if;
                        end if;

                        if State.Buttons (Index) = Last_State.Buttons (Index) then
                           if Value (Index) = Left_Shoulder
                             and State.Buttons (Index) = Pressed
                           then
                              Exposure := Exposure + 0.01;
                           end if;

                           if Value (Index) = Right_Shoulder
                             and State.Buttons (Index) = Pressed
                           then
                              Exposure := GL.Types.Single'Max (0.0, Exposure - 0.01);
                           end if;
                        end if;
                     end loop;
                  end;
               end if;

               if JS /= null then
                  declare
                     use Orka.Inputs.Joysticks.Gamepads;

                     State : constant Orka.Inputs.Joysticks.Joystick_State := JS.Current_State;

                     C_X : constant GL.Types.Double :=
                       GL.Types.Double (State.Axes (Index (Left_Stick_X)));
                     C_Y : constant GL.Types.Double :=
                       GL.Types.Double (State.Axes (Index (Left_Stick_Y)));
                     C_Z : constant GL.Types.Double :=
                       GL.Types.Double (State.Axes (Index (Right_Trigger)));

                     C_L : constant GL.Types.Double :=
                       EF.Sqrt (C_X ** 2 + C_Y ** 2);

                     C_L_A : constant GL.Types.Double :=
                        (if C_Y = 0.0 and C_X = 0.0 then
                           0.0
                         else
                           Orka.Transforms.Doubles.Vectors.To_Degrees (EF.Arctan (C_X, C_Y)));
                  begin
                     if abs C_X > 0.02 or abs C_Y > 0.02 then
                        Ada.Text_IO.Put_Line
                          (Image_D (C_X) & " " & Image_D (C_Y) & " = " & C_L'Image &
                           " d: " & Image_D (C_L_A));
                     end if;
                     Planet_Rotations := Planet_Rotations + C_X * 0.001;
--                     Atmosphere_Types.No_Behavior (Planet.all).Position :=
--                       (Earth.Bottom_Radius * C_X,
--                        Earth.Bottom_Radius * C_Y,
--                        Earth.Bottom_Radius * 0.0,
--                        1.0);

                     declare
                        S_Z : constant GL.Types.Double := GL.Types.Double (Step_Y) * 0.05;
                        Sun_Distance_AU : constant GL.Types.Double :=
                          ((1.0 - S_Z) * (1.0 - Min_AU) + Min_AU) * Planets.AU;
                     begin
                        Atmosphere_Types.No_Behavior (Sun.all).Position :=
                          (0.0, 0.0, Sun_Distance_AU, 1.0);
                     end;
                  end;
               end if;

--               if Camera.all in Observing_Camera'Class then
--                  TP := Observing_Camera'Class (Camera.all).Target_Position;
--               elsif Camera.all in First_Person_Camera'Class then
--                  TP := First_Person_Camera'Class (Camera.all).View_Position;
--               end if;

               declare
                  --  Currently we look at TP from a distance, and set the earth center
                  --  relative to this TP.
                  --
                  --  Try to Set earth center relative to camera and set distance to zero

--                  Distance : constant GL.Types.Double := Magnitude (TP - Camera.View_Position);
                  Distance : constant GL.Types.Double := Length (Sun.Position - Planet.Position);

                  use Orka.Logging;
               begin
                  Window.Set_Title
--                    ("Sun: " & Image_D (Distance / Planets.AU) & " AU "
--                    & "H: " & Image_D (Height_Above_Surface) & " m "
                    ("Meshlet:" & Terrain_Parameters.Meshlet_Subdivision'Image & " "
                    & "LOD stddev: " &
                        Image_D (Orka.Float_64 (Terrain_Parameters.Min_LoD_Standard_Dev)) & " "
                    & (if Use_Smap then "smap" else "no smap") & " "

                    & "Atmos: " & Trim (Image (GPU_Timers (1))) & " "
                    & "Terrain: " & Trim (Image (GPU_Timers (2))) & " ["

                    & "upd(" & Trim (Visible_Tiles'Image) & "): " &
                        Trim (Image (Terrain_Timers (1))) & " "
                    & "rnd: " & Trim (Image (Terrain_Timers (2))) & "] "

                    & "Frame: " & Trim (Image (GPU_Timers (3))) & " "
                    & "Res(" & Do_Blur'Image & "): " &
                      Trim (Image (GPU_Timers (4))) & " "

--                    & " expo:" & Exposure'Image

                    & "Sat:"
                    & Integer'Image (Integer (Atmosphere_Types.Physics_Behavior
                        (Object_01.all).FDM.Altitude)) & " m "
                    & Image_D (Matrices.Vectors.Length
                        (Atmosphere_Types.Physics_Behavior
                          (Object_01.all).Int.State.Velocity)) & " m/s"
                    );

                  Timer_2.Start;
                  if Render_Terrain then
                     Terrain_Manager_Helper.Render
                       (Terrain       => Terrain_Manager,
                        Parameters    => Terrain_Parameters,
                        Visible_Tiles => Visible_Tiles,
                        Camera        => Camera,
                        Planet        => Planet,
                        Star          => Sun,
                        Rotation      => Orientation_ECEF,
                        Center        => Move_To_Earth_Center,
                        Freeze        => Freeze_Terrain_Update,
                        Wires         => Show_Terrain_Wireframe,
                        Timer_Update  => Timer_Terrain_Update,
                        Timer_Render  => Timer_Terrain_Render);
                  end if;
                  New_Terrain_Timers (1) := Timer_Terrain_Update.GPU_Duration;
                  New_Terrain_Timers (2) := Timer_Terrain_Render.GPU_Duration;
                  Timer_2.Stop;
               end;

               Timer_1.Start;
               Atmosphere_Manager.Render (Camera, Planet, Sun);
               Timer_1.Stop;

               declare
                  Earth_Center_To_Camera : constant Matrices.Vector4 :=
                    Matrices.Vectors.Normalize (Coordinates.Inverse_Rotate_ECI
                      * (Camera.View_Position - Planet.Position));

                  F_ECTC : constant Matrices.Vector4 :=
                    Planets.Earth.Planet.Flattened_Vector (Earth_Center_To_Camera, 0.0);

                  Length_PTC : constant GL.Types.Double :=
                    Length (Planet.Position - Camera.View_Position);
                  Length_PTS : constant GL.Types.Double :=
                    Length ((F_ECTC (Orka.Y), F_ECTC (Orka.Z), F_ECTC (Orka.X), 0.0));
               begin
                  Height_Above_Surface := Length_PTC - Length_PTS;

                  pragma Assert (Height_Above_Surface >= Orka.Float_64'First);
                  --  Make compiler happy after removing it from window title
               end;

               for Index in Terrain_Timers'Range loop
                  Terrain_Timers (Index) :=
                    Duration'Max (Terrain_Timers (Index), New_Terrain_Timers (Index));
               end loop;

               GPU_Timers (1) := Duration'Max (GPU_Timers (1), Timer_1.GPU_Duration);
               GPU_Timers (2) := Duration'Max (GPU_Timers (2), Timer_2.GPU_Duration);
               GPU_Timers (3) := Duration'Max (GPU_Timers (3), Timer_0.GPU_Duration);
               GPU_Timers (4) := Duration'Max (GPU_Timers (4), Timer_4.GPU_Duration);

               Timer_3.Start;
               if Render_Debug_Geometry then
                  declare
                     Radius   : constant GL.Types.Single :=
                       GL.Types.Single
                         (Planets.Earth.Planet.Semi_Major_Axis / Earth.Length_Unit_In_Meters);

                     --  Bounding boxes
                     B_T : constant Orka.Types.Singles.Matrix4_Array :=
                       (Move_To_Earth_Center,
                        Move_To_Sphere_Center * Orientation_ECEF,
                        Move_To_Satellite_Center * Orientation_ECI);
                     B_B : constant Orka.Types.Singles.Vector4_Array :=
                       ((-Radius, -Radius, -Radius, 0.0), (Radius, Radius, Radius, 0.0),
                        (-1.0, -1.0, -1.0, 0.0), (1.0, 1.0, 1.0, 0.0),
                        (-1.0, -1.0, -1.0, 0.0), (1.0, 1.0, 1.0, 0.0));

                     --  Axes
                     A_T : constant Orka.Types.Singles.Matrix4_Array :=
                       (Move_To_Earth_Center,
                        Move_To_Earth_Center * Orientation_ECEF);
                     A_S : constant GL.Types.Single_Array := (1 => Radius);

                     --  Spheres
                     S_T_A : constant Orka.Types.Singles.Matrix4_Array :=
                       (1 .. GL.Types.Int (Sphere_Params_A.Length / 2) =>
                          Move_To_Earth_Center * Orientation_ECEF);

                     --  Lines
                     use Transforms.Vectors;

                     function Get_Lines (Object : Orka.Behaviors.Behavior_Ptr)
                       return Orka.Types.Singles.Vector4_Array
                     is
                        P : constant Orka.Types.Singles.Vector4 :=
                          Convert (Object.Position * (1.0 / Earth.Length_Unit_In_Meters));
                     begin
                        if Object.all in Atmosphere_Types.Physics_Behavior'Class then
                           declare
                              use all type Atmosphere_Types.Frame_Type;
                              PO : Atmosphere_Types.Physics_Behavior
                                renames Atmosphere_Types.Physics_Behavior (Object.all);

                              Foo : constant Matrices.Matrix4 :=
                                (case PO.Frame is
                                   when ECI  => Coordinates.Rotate_ECI,
                                   when ECEF => Coordinates.Rotate_ECEF);

                              V : constant Orka.Types.Singles.Vector4 :=
                                Convert (Foo * PO.Int.State.Velocity
                                    * (1.0 / Earth.Length_Unit_In_Meters));
                           begin
                              return ((0.0, 0.0, 0.0, 0.0), P, P, P + (50.0 * V));
                           end;
                        else
                           return ((0.0, 0.0, 0.0, 0.0), P);
                        end if;
                     end Get_Lines;

                     function Get_Lines (Point_In_ECEF : Orka.Types.Doubles.Vector4)
                       return Orka.Types.Singles.Vector4_Array
                     is
                        Scale_Factor : constant Orka.Float_64 :=
                          1.0 / Earth.Length_Unit_In_Meters;

                        Point_In_GL : constant Orka.Types.Singles.Vector4 :=
                          Convert (Coordinates.Rotate_ECEF * Point_In_ECEF * Scale_Factor);
                     begin
                        return ((0.0, 0.0, 0.0, 0.0), Point_In_GL);
                     end Get_Lines;

                     use type Orka.Types.Singles.Vector4_Array;

                     ECEF_XZ_15 : constant Orka.Types.Doubles.Vector4 :=
                       Planets.Earth.Planet.Geodetic_To_ECEF
                         (Latitude => 15.0, Longitude => 0.0, Altitude => 0.0);
                     ECEF_XZ_30 : constant Orka.Types.Doubles.Vector4 :=
                       Planets.Earth.Planet.Geodetic_To_ECEF
                         (Latitude => 30.0, Longitude => 0.0, Altitude => 0.0);
                     ECEF_XZ_45 : constant Orka.Types.Doubles.Vector4 :=
                       Planets.Earth.Planet.Geodetic_To_ECEF
                         (Latitude => 45.0, Longitude => 0.0, Altitude => 0.0);
                     ECEF_XZ_60 : constant Orka.Types.Doubles.Vector4 :=
                       Planets.Earth.Planet.Geodetic_To_ECEF
                         (Latitude => 60.0, Longitude => 00.0, Altitude => 0.0);
                     ECEF_XZ_75 : constant Orka.Types.Doubles.Vector4 :=
                       Planets.Earth.Planet.Geodetic_To_ECEF
                         (Latitude => 75.0, Longitude => 00.0, Altitude => 0.0);

                     To_Surface_At_0_0 : constant Orka.Types.Singles.Vector4_Array :=
                       (1 => (0.0, 0.0, 0.0, 0.0),
                        2 => Convert (Coordinates.Rotate_ECEF *
                          (Planets.Earth.Planet.Semi_Major_Axis, 0.0, 0.0, 1.0) *
                           (1.0 / Earth.Length_Unit_In_Meters)));
                     Planet_To_Sun : constant Orka.Types.Singles.Vector4_Array :=
                       (1 => (0.0, 0.0, 0.0, 0.0),
                        2 => Convert ((Sun.Position - Planet.Position)
                               * (1.0 / Earth.Length_Unit_In_Meters)));

                     --  Move the lines from the camera to the center of the Earth
                     L_T_ECEF : constant Orka.Types.Singles.Matrix4_Array :=
                       (1 => Move_To_Earth_Center);
                     L_T_ECI : constant Orka.Types.Singles.Matrix4_Array :=
                       (1 => Move_To_Earth_Center);

                     --  Magenta colored lines
                     L_C : constant Orka.Types.Singles.Vector4_Array :=
                       (1 => (1.0, 0.0, 1.0, 1.0));

                     L_P_ECI : constant Orka.Types.Singles.Vector4_Array :=
                       Get_Lines (Object_01);
                     L_P_ECEF : constant Orka.Types.Singles.Vector4_Array :=
--                       Get_Lines (Object_02) &
--                       Get_Lines (Object_03) &
                        Get_Lines (ECEF_XZ_15) &
                        Get_Lines (ECEF_XZ_30) &
                        Get_Lines (ECEF_XZ_45) &
                        Get_Lines (ECEF_XZ_60) &
                        Get_Lines (ECEF_XZ_75);
--                        To_Surface_At_0_0;
--                        Get_Lines (Sphere);
--                        Planet_To_Sun;
                  begin
                     BBox_Transforms.Set_Data (B_T);
                     BBox_Bounds.Set_Data (B_B);

                     Axes_Transforms.Set_Data (A_T);
                     Axes_Sizes.Set_Data (A_S);

                     Sphere_Transforms_A.Set_Data (S_T_A);

                     Line_Transforms_ECI.Set_Data (L_T_ECI);
                     Line_Transforms_ECEF.Set_Data (L_T_ECEF);
                     Line_Colors.Set_Data (L_C);
                     Line_Points_ECI.Set_Data (L_P_ECI);
                     Line_Points_ECEF.Set_Data (L_P_ECEF);

                     BBox.Render
                       (View       => Camera.View_Matrix,
                        Proj       => Lens.Projection_Matrix,
                        Transforms => BBox_Transforms,
                        Bounds     => BBox_Bounds);

                     Axis.Render
                       (View       => Camera.View_Matrix,
                        Proj       => Lens.Projection_Matrix,
                        Transforms => Axes_Transforms,
                        Sizes      => Axes_Sizes);

                     if Show_White_Grid then
                        Debug_Sphere.Render
                          (View       => Camera.View_Matrix,
                           Proj       => Lens.Projection_Matrix,
                           Transforms => Sphere_Transforms_A,
                           Spheres    => Sphere_Params_A);
                     end if;

                     if Show_Stationary_Targets then
                        Line.Render
                          (View       => Camera.View_Matrix,
                           Proj       => Lens.Projection_Matrix,
                           Transforms => Line_Transforms_ECEF,
                           Colors     => Line_Colors,
                           Points     => Line_Points_ECEF);
                     end if;

                     if Show_Satellites then
                        Line.Render
                          (View       => Camera.View_Matrix,
                           Proj       => Lens.Projection_Matrix,
                           Transforms => Line_Transforms_ECI,
                           Colors     => Line_Colors,
                           Points     => Line_Points_ECI);
                     end if;
                  end;
               end if;
               Timer_3.Stop;

               pragma Assert (Samples > 0);
               if Do_Blur /= None then
                  FB_3.Use_Framebuffer;
               else
                  FB_D.Use_Framebuffer;
               end if;
               P_2.Use_Program;
               Orka.Rendering.Textures.Bind (Texture_1, Orka.Rendering.Textures.Texture, 0);

               if Do_White_Balance then
                  P_2.Uniform ("white_point").Set_Vector
                    (White_Points);
               else
                  P_2.Uniform ("white_point").Set_Vector
                    (GL.Types.Single_Array'((1.0, 1.0, 1.0)));
               end if;

               P_2.Uniform ("samples").Set_Int (Samples);

               if Do_Blur /= None then
                  P_2.Uniform ("screenResolution").Set_Vector
                    (Orka.Types.Singles.Vector4'
                      (GL.Types.Single (FB_3.Width), GL.Types.Single (FB_3.Height), 0.0, 0.0));
               else
                  P_2.Uniform ("screenResolution").Set_Vector
                    (Orka.Types.Singles.Vector4'
                      (GL.Types.Single (FB_D.Width), GL.Types.Single (FB_D.Height), 0.0, 0.0));
               end if;

               P_2.Uniform ("exposure").Set_Single
                 ((if Earth.Luminance /= Orka.Features.Atmosphere.None then
                     Exposure * 1.0e-5
                   else Exposure));

               Timer_4.Start;
               GL.Buffers.Set_Depth_Function (GL.Types.Always);
               Orka.Rendering.Drawing.Draw (GL.Types.Triangles, 0, 3);
               GL.Buffers.Set_Depth_Function (GL.Types.Greater);

               case Do_Blur is
                  when None =>
                     null;
                  when Moving_Average =>
                     FB_3.Resolve_To (FB_4);
                     Blur_Filter_MA (Blur_Kernel_Size).Render (Passes => 2);
                     FB_4.Resolve_To (FB_D);
                  when Gaussian =>
                     FB_3.Resolve_To (FB_4);
                     Blur_Filter_GK (Blur_Kernel_Size).Render (Passes => 1);
                     FB_4.Resolve_To (FB_D);
               end case;
               Timer_4.Stop;

               Timer_0.Stop;

               if Previous_Viewed_Object /= Current_Viewed_Object then
                  Update_Viewed_Object (Camera, Current_Viewed_Object);
               end if;

               Window.Swap_Buffers;

               if Window.Should_Close then
                  Loops.Stop_Loop;
               end if;
            end Render_Scene;

            T2 : constant Time := Clock;
         begin
            Ada.Text_IO.Put_Line ("Load time: " &
              Duration'Image (To_Duration (T2 - T1)));
            Ada.Text_IO.Put_Line ("Bottom radius model:  " & Earth.Bottom_Radius'Image);

            Loops.Scene.Add (Sphere);
            Loops.Scene.Add (Object_01);
            Loops.Scene.Add (Object_02);
            Loops.Scene.Add (Object_03);

            Loops.Handler.Enable_Limit (False);

            declare
               task Render_Task is
                  entry Start_Rendering;
               end Render_Task;

               task body Render_Task is
               begin
                  accept Start_Rendering;

                  Context.Make_Current (Window);
                  Loops.Run_Loop (Render_Scene'Access);
                  Context.Make_Not_Current;
               exception
                  when Error : others =>
                     Ada.Text_IO.Put_Line ("Error: " &
                       Ada.Exceptions.Exception_Information (Error));
                     Context.Make_Not_Current;
                     raise;
               end Render_Task;

               Next_Cursor : AWT.Inputs.Cursors.Pointer_Cursor :=
                 AWT.Inputs.Cursors.Pointer_Cursor'First;
            begin
               Context.Make_Not_Current;
               Render_Task.Start_Rendering;

               while not Window.Should_Close loop
                  AWT.Process_Events (0.016667);

                  declare
                     Keyboard : constant AWT.Inputs.Keyboard_State := Window.State;

                     use all type AWT.Inputs.Keyboard_Button;
                     use type AWT.Inputs.Cursors.Pointer_Cursor;
                  begin
                     if Keyboard.Pressed (Key_Escape) then
                        Window.Close;
                     end if;

                     if Keyboard.Pressed (Key_C) then
                        Next_Cursor :=
                          (if Next_Cursor = AWT.Inputs.Cursors.Pointer_Cursor'Last then
                             AWT.Inputs.Cursors.Pointer_Cursor'First
                           else
                             AWT.Inputs.Cursors.Pointer_Cursor'Succ (Next_Cursor));
                        Window.Set_Pointer_Cursor (Next_Cursor);
                     end if;
                  end;
               end loop;
               Ada.Text_IO.Put_Line ("Exited event loop in main task");
            end;
         end;
      end;
   end;

   Ada.Text_IO.Put_Line ("Shutting down...");
   Demo.Job_System.Shutdown;
   Ada.Text_IO.Put_Line ("Shut down");
exception
   when Error : others =>
      Ada.Text_IO.Put_Line ("Error: " & Ada.Exceptions.Exception_Information (Error));
      Demo.Job_System.Shutdown;
end Orka_Demo;
