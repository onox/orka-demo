with Ada.Unchecked_Deallocation;

with GL.Types;

with Orka.Transforms.Doubles.Quaternions;
with Orka.Transforms.Doubles.Vectors;

package Integrators is
   pragma Preelaborate;

   package Quaternions renames Orka.Transforms.Doubles.Quaternions;
   package Vectors     renames Orka.Transforms.Doubles.Vectors;

   type Force_At_Point is record
      Force, Point : Vectors.Vector4;
   end record;

   type Force_At_Point_Array is array (Positive range <>) of Force_At_Point;

   subtype Moment is Vectors.Vector4;

   type Moment_Array is array (Positive range <>) of Moment;

   type Integrator_State is record
      Position, Momentum, Velocity       : Vectors.Vector4;
      Orientation                        : Quaternions.Quaternion;
      Angular_Momentum, Angular_Velocity : Vectors.Vector4;
   end record;

   -----------------------------------------------------------------------------

   type Force_Array_Access  is access Force_At_Point_Array;
   type Moment_Array_Access is access Moment_Array;

   procedure Free is new Ada.Unchecked_Deallocation (Force_At_Point_Array, Force_Array_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Moment_Array, Moment_Array_Access);

   -----------------------------------------------------------------------------

   type Physics_Object is interface;

   procedure Update
     (Object : in out Physics_Object;
      State  : Integrator_State;
      Delta_Time : Duration) is null;

   function Forces (Object : Physics_Object) return Force_Array_Access is abstract;
   --  Return a list of forces applied at certain points. X axis is forward,
   --  Y is right, and Z is down.

   function Moments (Object : Physics_Object) return Moment_Array_Access is abstract;

   function Inverse_Mass (Object : Physics_Object) return GL.Types.Double is abstract;

   function Inverse_Inertia (Object : Physics_Object) return GL.Types.Double is abstract;

   function Center_Of_Mass (Object : Physics_Object) return Vectors.Vector4 is abstract;

   ----------------------------------------------------------------------

   type Integrator is interface;

   procedure Integrate
     (Object  : in out Integrator;
      Subject : in out Physics_Object'Class;
      T, DT   : GL.Types.Double) is abstract;

   function State (Object : Integrator) return Integrator_State is abstract;

end Integrators;
