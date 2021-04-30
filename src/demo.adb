with Orka.Windows;

with AWT.Inputs;

package body Demo is

   overriding
   function On_Close (Object : Test_Window) return Boolean is
   begin
      Messages.Log (Debug, "Close window?");
      return True;
   end On_Close;

   overriding
   procedure On_Configure
     (Object       : in out Test_Window;
      State        : Standard.AWT.Windows.Window_State) is
   begin
      Messages.Log (Debug, "Configure xdg_surface:" &
        State.Width'Image & State.Height'Image & State.Margin'Image & " " & State.Visible'Image);

      Object.Resize := State.Visible and State.Width > 0 and State.Height > 0;
   end On_Configure;

   overriding
   function Create_Window
     (Context            : Orka.Contexts.Surface_Context'Class;
      Width, Height      : Positive;
      Title              : String  := "";
      Samples            : Natural := 0;
      Visible, Resizable : Boolean := True;
      Transparent        : Boolean := False) return Test_Window is
   begin
      return Result : constant Test_Window :=
        (Orka.Contexts.AWT.Create_Window
          (Context, Width, Height, Title, Samples,
           Visible     => Visible,
           Resizable   => Resizable,
           Transparent => Transparent) with others => <>);
   end Create_Window;

end Demo;
