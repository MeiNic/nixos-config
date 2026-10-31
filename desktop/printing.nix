# Printing (CUPS)
{ pkgs, ... }:

{
  services.printing.enable = true;
  services.printing.drivers = with pkgs; [
    gutenprint
    gutenprintBin
    ghostscript
    mfcj470dwlpr           # Brother MFC-J470DW LPR driver (compatible with J497DW)
    mfcj470dw-cupswrapper  # CUPS wrapper for the above
  ];
}
