with Orka.Jobs.System;

package Demo is

   package Job_System is new Orka.Jobs.System
     (Maximum_Queued_Jobs => 16,
      Maximum_Job_Graphs  => 4);

end Demo;
