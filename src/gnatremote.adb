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

-- Build tree (simplified)
--
--  /root
--  └── build
--      └── hex01         Project root
--          ├── alire
--          ├── hex01     Directory gathering common sources, must have the project name
--          ├── hex01_net Net program folder
--          │   ├── alire
--          │   ├── obj
--          │   ├── prg
--          │   └── src
--          ├── hex01_tsk Tsk program folder
--          │   ├── alire
--          │   ├── config
--          │   ├── obj
--          │   ├── prg
--          │   └── src
--          ├── hex01_web Web program folder
--          │   ├── alire
--          │   ├── obj
--          │   ├── prg
--          │   └── src
--          ├── prg
--          ├── src
--          └── v22
--              ├── alire
--              ├── lib
--              └── prg
--
--
--  Execution tree dev & prod
--
--  /opt
--  └── hex01                 Projet root
--      ├── dev               Dev directory
--      │   ├── css
--      │   ├── html
--      │   │   └── downloads
--      │   ├── img
--      │   ├── js
--      │   └── sys           Systemd services files
--      └── prod              Prod directory
--          ├── css
--          ├── html
--          │   └── downloads
--          ├── img
--          ├── js
--          └── sys           Systemd services files


--  # -----------------------------------------------------------------------------
--  #  gnatremote.cfg - Configuration file
--  # -----------------------------------------------------------------------------
--  #
--  #  20240521-153805 - gnatremote v0.6
--  #
--  # -----------------------------------------------------------------------------
--
--  [Project]
--  Name = hex01
--  # Project name
--
--  [Program]
--  Name = hex01_net
--  Sources_Dir = src
--  Libraries_Dir = v22
--  Objects_Dir = obj
--  Binary_Dir = bin
--  # Relative directory (./src) from root program directory
--  # Relative directory (../v22/lib) from root program directory
--  # Relative directory (./obj) from root program directory
--  # Relative directory (./bin) from root program directory
--
--  [Local]
--  Beep = bell
--  # Beep after successful build (bell/ansi/none)
--
--  [Remote]
--  Host = id.domain.tld
--  User = root
--  Build_Dir = /root/build
--  Run_Dir = /opt
--  Dev_Dir = dev
--  Prod_Dir = prod
--  # Root build directory
--  # Run directory
--  # Relative directory (./dev) from run directory
--  # Relative directory (./prod) from run directory
--
--  # -----------------------------------------------------------------------------
--  #  EOF
--  # -----------------------------------------------------------------------------

pragma Ada_2012;

with System;

with Ada.Calendar;
with Ada.Exceptions;

with GNAT.Calendar.Time_IO;
with GNAT.Command_Line;
with GNAT.OS_Lib;
with GNAT.Strings;
with GNAT.Sockets;

with UXStrings; use UXStrings;

with v22; use v22;
with v22.Cfg;
with v22.Fls;
with v22.Msg;
with v22.Net;
with v22.Prg;
with v22.Sys;
with v22.Tio;
with v22.Uxs; use v22.Uxs;

procedure GnatRemote is

   package AC  renames Ada.Calendar;
   package GCT renames GNAT.Calendar.Time_IO;
   package GCL renames GNAT.Command_Line;
   package GOL renames GNAT.OS_Lib;
   package GS renames GNAT.Strings;

   ----------------------------------------------------------------------------
   --  PUBLIC TYPES
   ----------------------------------------------------------------------------

   subtype String is UXString;

   type Config_Type is record
      Project_Name : String;
      Program_Name : String;
      Program_Sources_Dir : String;
      Program_Libraries_Dir : String;
      Program_Objects_Dir : String;
      Program_Binary_Dir : String;
      Local_Beep : String;
      Remote_Host : String;
      Remote_User : String;
      Remote_Build_Dir : String;
      Remote_Run_Dir : String;
      Remote_Dev_Dir : String;
      Remote_Prod_Dir : String;
      Action : String;
   end record;

   ----------------------------------------------------------------------------
   --  PUBLIC VARIABLES
   ----------------------------------------------------------------------------

   Config : Config_Type;
   Result : Boolean := True;

   ----------------------------------------------------------------------------
   --  PROCEDURES & FUNCTIONS
   ----------------------------------------------------------------------------

   ----------------------------------------------------------------------------
   package Ini is
      function App return Boolean;
      --  Initialize application
   end Ini;
   package body Ini is separate;

   ----------------------------------------------------------------------------
   procedure Beep is
   begin
      if (Config.Local_Beep = "ansi") then
         Tio.Beep;
      elsif (Config.Local_Beep = "bell") then
         Tio.Bell;
      end if;
   end Beep;

   ----------------------------------------------------------------------------
   function Copy_Common return Boolean is
      Dummy : Boolean;
   begin
      Msg.Title (Prg.Name & ".Copy_Common > Copy common project sources");

      --  Copy relative directory (../src) gathering common sources from root project directory
      Dummy := Net.Copy_Rsync (Target => Config.Remote_User & "@" & Config.Remote_Host,
      -- <root program>/../
                               Directory_Tx => Prg.Start_Dir & "/../" & Config.Project_Name & "/",
                               Directory_Rx => Config.Remote_Build_Dir & "/" & Config.Project_Name,
                               Excludes_Directories => ".*:" & Config.Program_Binary_Dir & ":" &
                                                               Config.Program_Objects_Dir);
      return True;
   end Copy_Common;

   ----------------------------------------------------------------------------
   function Copy_Src return Boolean is
   begin
      Msg.Title (Prg.Name & ".Copy_Src > Copy build files and program sources");

      --  We not only copy ./src files but build files and alire directory
      return Net.Copy_Rsync (Target => Config.Remote_User & "@" & Config.Remote_Host,
                             Directory_Tx => Prg.Start_Dir & "/",
                             Directory_Rx => Config.Remote_Build_Dir & "/" & Config.Program_Name,
                             Excludes_Directories => ".*:" & Config.Program_Binary_Dir & ":" &
                                                             Config.Program_Objects_Dir);
   end Copy_Src;

   ----------------------------------------------------------------------------
   function Copy_Lib return Boolean is
   begin
      Msg.Title (Prg.Name & ".Copy_Lib > Copy libraries sources");

      return Net.Copy_Rsync (Target => Config.Remote_User & "@" & Config.Remote_Host,
                             Directory_Tx => Prg.Start_Dir & "/../" & Config.Program_Libraries_Dir & "/",
                             Directory_Rx => Config.Remote_Build_Dir & "/" & Config.Program_Libraries_Dir,
                             Excludes_Directories => ".*:tools:" & Config.Program_Binary_Dir & ":" &
                                                                   Config.Program_Objects_Dir & ":" &
                                                                   Config.Program_Sources_Dir);
   end Copy_Lib;

   ----------------------------------------------------------------------------
   function Build (Method : String := "full") return Boolean is
      Object_Directory : String := Config.Remote_Build_Dir & "/" & Config.Program_Name & "/" & Config.Program_Objects_Dir;
      Main_Binary : String := Config.Remote_Build_Dir & "/" & Config.Program_Name & "/" & Config.Program_Binary_Dir & "/" & Config.Program_Name;

      Result : Boolean;
      Output : String;
   begin
      Msg.Title (Prg.Name & ".Build > " & Config.Program_Name);

      --  The Main_Object file must be deleted as it reflects build date stamp read by v22.Get_Build function.
      --  In addition, to avoid problems (1) of dependency on the local system, remote object directory
      --  should be cleaned of any objects (or entirely wiped) from the previous compilation process.
      --
      --  (1) ./hex01_web: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.33' not found (required by ./hex01_web)
      --      ./hex01_web: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.34' not found (required by ./hex01_web)
      --      ./hex01_web: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.32' not found (required by ./hex01_web)

      if Method = "full" then
         if Net.Delete_Directory_Tree (Config.Remote_User & "@" & Config.Remote_Host, Object_Directory) then
            Msg.Info (Object_Directory & " successfully deleted");
         else
            Msg.Info (Object_Directory & " not deleted, build date will be incorrect and/or dependencies problems could arise");
         end if;
      end if;

      --  Delete main binary
      if Net.File_Exists (Config.Remote_User & "@" & Config.Remote_Host, Main_Binary) then
         if Net.Delete_File (Config.Remote_User & "@" & Config.Remote_Host, Main_Binary) then
            Msg.Info (Main_Binary & " successfully deleted");
         else
            Msg.Error (Main_Binary & " not deleted, build date will be incorrect");
         end if;
      else
         Msg.Info (Main_Binary & " not found and therefore not deleted");
      end if;

      --  Build
      Result := Net.Command (Config.Remote_User & "@" & Config.Remote_Host,
                                                "cd " & Config.Remote_Build_Dir & "/" &
                                                        Config.Program_Name & " ; alr build ; ls -l ./" &
                                                        Config.Program_Binary_Dir, Output);
      --  Build output
      Tio.Put_Line (Output);
      return Result;
   end Build;

   ----------------------------------------------------------------------------
   function Restart (Destination : String) return Boolean is
      Result : Boolean := False;
      Command : String;
      Output : String;
   begin

      if Index (Config.Remote_Run_Dir, "none") = 0 then
         Msg.Title (Prg.Name & ".Restart > " & Config.Program_Name);

         if Net.Command (Config.Remote_User & "@" & Config.Remote_Host,
                         "systemctl stop " & Config.Program_Name & "_" & Destination, Output) then
            if not Is_Empty (Output) then
               Tio.Put_Line (Output);
            end if;
            -- cp --force /root/build/hex01/hex01_net/prg/hex01_net /opt/hex01/hex01_net_dev on root@id.domain.tld successful
            Command := "cp --force " & --  Tx
              Config.Remote_Build_Dir   & "/" & Config.Program_Name & "/" &
              Config.Program_Binary_Dir & "/" & Config.Program_Name & " " &
            --  Rx
              Config.Remote_Run_Dir     & "/" & Destination & "/" &
              Config.Program_Name & "_" & Destination;

            if Net.Command (Config.Remote_User & "@" & Config.Remote_Host, Command, Output) then
               if not Is_Empty (Output) then
                  Tio.Put_Line (Output);
               end if;
               if Net.Command (Config.Remote_User & "@" & Config.Remote_Host,
                               "systemctl start " & Config.Program_Name & "_" & Destination, Output) then
                  if not Is_Empty (Output) then
                     Tio.Put_Line (Output);
                  end if;
                  Result := True;
               else
                  Msg.Error (Prg.Name & ".Restart > systemctl start " & Config.Program_Name & "_" & Destination &" failed");
               end if;
            else
               Msg.Error (Prg.Name & ".Restart > " & Command & " failed");
            end if;
         else
            Msg.Error (Prg.Name & ".Restart > systemctl stop " & Config.Program_Name & "_" & Destination & " failed");
         end if;
      else
         Result := True;
      end if;

      return Result;

   end Restart;

-------------------------------------------------------------------------------
--  Main
-------------------------------------------------------------------------------

begin

   if Ini.App then

      Msg.Set_Task ("ACTION");

      Msg.New_Line;
      Msg.Title (Prg.Name & ".Main > Parameters");

      Msg.Info ("Local directory: " & Prg.Start_Dir);
      Msg.Info ("Action required: " & Config.Action);
      Msg.Info ("Source directory: " & Prg.Start_Dir);

      Msg.Info ("Remote build directory:    " & Config.Remote_User & "@" & Config.Remote_Host &       Config.Remote_Build_Dir);
      Msg.Info ("Remote run dir directory:  " & Config.Remote_User & "@" & Config.Remote_Host &       Config.Remote_Run_Dir);
      Msg.Info ("Remote run dev directory:  " & Config.Remote_User & "@" & Config.Remote_Host & "/" & Config.Remote_Dev_Dir);
      Msg.Info ("Remote run prod directory: " & Config.Remote_User & "@" & Config.Remote_Host & "/" & Config.Remote_Prod_Dir);

      if Config.Action = "dev_save_copy_build_fast_restart" then
         Result := Copy_Common and Copy_Src and Copy_Lib and Build ("fast") and Restart (Config.Remote_Dev_Dir);
      elsif Config.Action = "prod_save_copy_build_fast_restart" then
         Result := Copy_Common and Copy_Src and Copy_Lib and Build ("fast") and Restart (Config.Remote_Prod_Dir);
      elsif Config.Action = "dev_save_copy_build_full_restart" then
         Result := Copy_Common and Copy_Src and Copy_Lib and Build ("full") and Restart (Config.Remote_Dev_Dir);
      elsif Config.Action = "prod_save_copy_build_full_restart" then
         Result := Copy_Common and Copy_Src and Copy_Lib and Build ("full") and Restart (Config.Remote_Prod_Dir);
      else
         Msg.Info ("No action given");
      end if;

      if Result then
         Msg.Info ("Action successful");
         Beep;
      end if;

   end if;

   Finalize;

exception

   --  -h or --help switches
   when GCL.Exit_From_Command_Line =>
      --Help;
      GOL.OS_Exit (1);

   --  Runtime errors
   when Error : others =>
      v22.Exception_Handling (Error);

-----------------------------------------------------------------------------
end GnatRemote;
-----------------------------------------------------------------------------
