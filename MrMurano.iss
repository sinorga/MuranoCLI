[Setup]
AppName=MrMurano
AppVersion={%MRVERSION}
DefaultDirName={pf}\MrMurano
DefaultGroupName=MrMurano
ChangesEnvironment=yes
OutputBaseFileName=MrMuranoSetup
AppPublisher=Exosite
AppPublisherURL=http://exosite.com/
AppCopyright=Copyright (C) 2016-2017 Exosite
LicenseFile=LICENSE.txt

[Files]
Source: "mr.exe"; DestDir: "{app}\bin"
Source: "LICENSE.txt"; DestDir: "{app}"
Source: "ReadMe.txt"; DestDir: "{app}"; Flags: isreadme

; http://www.jrsoftware.org/ishelp/

;;;;;;;;;;;;;;;;;;;;;;;;;
; http://stackoverflow.com/questions/3304463/how-do-i-modify-the-path-environment-variable-when-running-an-inno-setup-install/3431379
[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; \
    ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}\bin"; \
    Check: NeedsAddPath('{app}\bin')

;;; Not working.
[Code]

function NeedsAddPath(Param: string): boolean;
var
  OrigPath: string;
  ParamExpanded: string;
begin
  //expand the setup constants like {app} from Param
  ParamExpanded := ExpandConstant(Param);
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', OrigPath)
  then begin
    Result := True;
    exit;
  end;
  // look for the path with leading and trailing semicolon and with or without \ ending
  // Pos() returns 0 if not found
  Result := Pos(';' + UpperCase(ParamExpanded) + ';', ';' + UpperCase(OrigPath) + ';') = 0;
  if Result = True then
     Result := Pos(';' + UpperCase(ParamExpanded) + '\;', ';' + UpperCase(OrigPath) + ';') = 0;
end;

