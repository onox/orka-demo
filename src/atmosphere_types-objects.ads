package Atmosphere_Types.Objects is
   pragma Elaborate_Body;

   Object_01 : constant Orka.Behaviors.Behavior_Ptr := new Physics_Behavior'
     (Frame => ECI, others => <>);

   Object_02 : constant Orka.Behaviors.Behavior_Ptr := new Physics_Behavior'
     (Frame => ECEF, others => <>);
   Object_03 : constant Orka.Behaviors.Behavior_Ptr := new Physics_Behavior'
     (Frame => ECEF, others => <>);

end Atmosphere_Types.Objects;
