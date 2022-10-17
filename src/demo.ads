with Orka.Jobs.System;
with Orka.Logging.Default;

package Demo is

   package Job_System is new Orka.Jobs.System
     (Maximum_Queued_Jobs => 16,
      Maximum_Job_Graphs  => 4);

   use all type Orka.Logging.Default_Module;

   procedure Log is new Orka.Logging.Default.Generic_Log (Window_System);

end Demo;
