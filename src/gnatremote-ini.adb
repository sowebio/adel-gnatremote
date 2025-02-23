------------------------------------------------------------------------------
--  @file      gnatremote.adb
--  @copyright See authors list below README.md file
--  @licence   LGPL v3
--  @encoding  UTF-8
------------------------------------------------------------------------------
--  @summary
--  Gnatstudio remote utility
--
--  @description
--
--
--  @authors
--  Stéphane Rivière - sr - sriviere@soweb.io
--
--  @versions
--  See git log
------------------------------------------------------------------------------

with System;

with Ada.Exceptions;

with v22.Msg;

separate (GnatRemote) package body Ini is

   ----------------------------------------------------------------------------
   --  API
   ----------------------------------------------------------------------------

   ----------------------------------------------------------------------------
   function App return Boolean is
      Init_Success : Boolean := False;

      GCL_Config : GCL.Command_Line_Configuration;
      Gcl_Action : aliased GS.String_Access;
      Gcl_Check_Error_Trace : aliased Boolean := False;

   begin

      --  Settings
      Prg.Set_Version (0, 9);

      Prg.Set_Handler_Ctrl_C (On);
      Sys.Set_Memory_Monitor (On);

      Msg.Set_Header (On);
      Msg.Set_Disk (On);
      Msg.Set_Display (On);

      Msg.Set_Debug (Off);
      Tio.Set_Ansi (Off);  -- No ANSI when ouputing in GnatStudio
      Tio.Set_Cursor (Off); -- No cursor Off when ouputing in GnatStudio

      Tio.New_Line;
      Tio.Put_Line ("GnatRemote - Gnatstudio remote utility");
      Tio.Put_Line ("Copyright (C) Sowebio SARL 2023-" & From_Latin_1 (GCT.Image (AC.Clock, "%Y")));
      Tio.Put_Line (Prg.Get_Version & " - " & v22.Get_Version & " - " & v22.Get_Build);
      Tio.New_Line;

      ----------------------------------------------------------------------------
      --  Command line parameters handling
      ----------------------------------------------------------------------------

      GCL.Set_Usage (GCL_Config, Usage => "[switches] [arguments] overview", Help =>  "This is the short help text");

      GCL.Define_Switch (GCL_Config, Gcl_Action'Access,
                         Switch => "-a=",
                         Long_Switch => "--action=",
                         Argument => "Action command",
                         Help =>                              "dev_save_copy_build_fast_restart|" & To_Latin_1 (CRLF) &
                                 "                             prod_save_copy_build_fast_restart|" & To_Latin_1 (CRLF) &
                                 "                             dev_save_copy_build_full_restart|" & To_Latin_1 (CRLF) &
                                 "                             prod_save_copy_build_full_restart" & To_Latin_1 (CRLF)
                         );

      GCL.Define_Switch (GCL_Config, Gcl_Check_Error_Trace'Access,
                         Switch => "-e",
                         Long_Switch => "--check-error-trace",
                         Help => "Check .err trace raising an exception" & To_Latin_1 (CRLF));

      GCL.Getopt (GCL_Config); --  Command line processing

      --  Arguments processing

      Config.Action := From_Latin_1 (Gcl_Action.all);

      if Gcl_Check_Error_Trace then
         Msg.Error (Prg.Name & ".Init.App > Exception test trigered by a raise exception");
         Raise_Exception;
      end if;

      ----------------------------------------------------------------------------
      --  Configuration file management
      ----------------------------------------------------------------------------

      if not Fls.Exists (Cfg.Get_Name) then
         if Cfg.Open then
            Cfg.Comment ("-----------------------------------------------------------------------------");
            Cfg.Comment (" " & Prg.Name & ".cfg - Configuration file");
            Cfg.Comment ("-----------------------------------------------------------------------------");
            Cfg.Comment ("");
            Cfg.Comment (" " & Prg.Date_Time_Stamp & " - " & Prg.Get_Version);
            Cfg.Comment ("");
            Cfg.Comment ("-----------------------------------------------------------------------------");
            Cfg.New_Line;
            Cfg.Comment ("All paths are relative apart Build_Dir and Run_Dir");
            Cfg.New_Line;

            --  Per section, reverse order in code as insert is allways done at the beginning of a section

            Cfg.Set ("Project", "Name", "hex01");
            Cfg.Comment ("Project name");
            Cfg.New_Line;

            Cfg.Set ("Program", "Binary_Dir", "bin");
            Cfg.Set ("Program", "Objects_Dir", "obj");
            Cfg.Set ("Program", "Libraries_Dir", "v22");
            Cfg.Set ("Program", "Sources_Dir", "src");
            Cfg.Set ("Program", "Name", "project_name");
            Cfg.Comment ("Relative directory (./src) from root program directory");
            Cfg.Comment ("Relative directory (../v22/lib) from root program directory");
            Cfg.Comment ("Relative directory (./obj) from root program directory");
            Cfg.Comment ("Relative directory (./bin) from root program directory");
            Cfg.New_Line;

            Cfg.Set ("Local", "Beep", "bell");
            Cfg.Comment ("Beep after successful build (bell/ansi/none)");
            Cfg.New_Line;

            Cfg.Set ("Remote", "Prod_Dir", "prod");
            Cfg.Set ("Remote", "Dev_Dir", "dev");
            Cfg.Set ("Remote", "Run_Dir", "/opt");
            Cfg.Set ("Remote", "Build_Dir", "/root/build");
            Cfg.Set ("Remote", "User", "root");
            Cfg.Set ("Remote", "Host", "id.domain.tld");
            Cfg.Comment ("Build directory");
            Cfg.Comment ("Run directory");
            Cfg.Comment ("Relative directory (./dev) from run directory");
            Cfg.Comment ("Relative directory (./prod) from run directory");

            Cfg.New_Line;

            Cfg.Comment ("-----------------------------------------------------------------------------");
            Cfg.Comment (" EOF");
            Cfg.Comment ("-----------------------------------------------------------------------------");
            Cfg.Close;
            Msg.Info (Prg.Name & ".Init.App > Configuration file " & Cfg.Get_Name & " has been created");
         end if;
      end if;

      if Cfg.Open then

         Config.Project_Name := Cfg.Get ("Project", "Name");

         Config.Program_Name := Cfg.Get ("Program", "Name");
         Config.Program_Name_Full := Config.Project_Name & "_" & Cfg.Get ("Program", "Name");
         Config.Program_Sources_Dir := Cfg.Get ("Program", "Sources_Dir");
         Config.Program_Objects_Dir := Cfg.Get ("Program", "Objects_Dir");
         Config.Program_Binary_Dir := Cfg.Get ("Program", "Binary_Dir");

         Config.Local_Beep := Cfg.Get ("Local", "Beep");

         Config.Remote_Host := Cfg.Get ("Remote", "Host");
         Config.Remote_User := Cfg.Get ("Remote", "User");
         Config.Remote_Build_Dir := Cfg.Get ("Remote", "Build_Dir") & "/" & Config.Project_Name;
         Config.Remote_Run_Dir := Cfg.Get ("Remote", "Run_Dir") & "/" & Config.Project_Name;
         Config.Remote_Dev_Dir := Cfg.Get ("Remote", "Dev_Dir");
         Config.Remote_Prod_Dir := Cfg.Get ("Remote", "Prod_Dir");

         Msg.Info (Prg.Name & ".Init.App > Configuration file ../" & Tail_After_Match (Cfg.Get_Name, '/') & " loaded");

         Init_Success := True;

         --  Place holder for parameters validation
         --
         --

      end if;

      return Init_Success;

   end App;

-------------------------------------------------------------------------------
end Ini;
-------------------------------------------------------------------------------
