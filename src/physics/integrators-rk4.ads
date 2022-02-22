package Integrators.RK4 is
   pragma Preelaborate;

   --  Runge Kutta order 4 integrator

   type RK4_Integrator is new Integrator with private;

   overriding
   procedure Integrate
     (Object  : in out RK4_Integrator;
      Subject : in out Physics_Object'Class;
      T, DT   : Orka.Float_64);

   overriding
   function State (Object : RK4_Integrator) return Integrator_State;

   function Create_Integrator
     (Subject     : Physics_Object'Class;
      Position    : Vectors.Vector4;
      Velocity    : Vectors.Vector4;
      Orientation : Quaternions.Quaternion := Quaternions.Identity) return RK4_Integrator;

private

   type Linear_State is record
      Position, Momentum, Velocity : Vectors.Vector4 := Vectors.Vector4 (Vectors.Zero_Point);
      Inverse_Mass : Orka.Float_64;
   end record;

   type Angular_State is record
      Orientation : Quaternions.Quaternion := Quaternions.Identity;
      Angular_Momentum, Angular_Velocity : Vectors.Vector4 := Vectors.Vector4 (Vectors.Zero_Point);
      Inverse_Inertia : Orka.Float_64;
   end record;

   type RK4_Integrator is new Integrator with record
      Linear  : Linear_State;
      Angular : Angular_State;
   end record;

end Integrators.RK4;
