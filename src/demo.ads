with Orka.Contexts.AWT;
with Orka.Jobs.System;
with Orka.Logging;

with AWT.Windows;

package Demo is

   package Job_System is new Orka.Jobs.System
     (Maximum_Queued_Jobs => 16,
      Maximum_Job_Graphs  => 4);

   use all type Orka.Logging.Source;
   use all type Orka.Logging.Severity;
   use Orka.Logging;

   package Messages is new Orka.Logging.Messages (Window_System);

   type Test_Window is limited new Orka.Contexts.AWT.AWT_Window with record
      Resize : Boolean := True with Atomic;
   end record;

   overriding
   function On_Close (Object : Test_Window) return Boolean;

   overriding
   procedure On_Configure
     (Object       : in out Test_Window;
      State        : Standard.AWT.Windows.Window_State);

   overriding
   function Create_Window
     (Context            : Orka.Contexts.Surface_Context'Class;
      Width, Height      : Positive;
      Title              : String  := "";
      Samples            : Natural := 0;
      Visible, Resizable : Boolean := True;
      Transparent        : Boolean := False) return Test_Window;

end Demo;
