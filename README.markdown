# About

This plugin was written to make it easier to project the view direction along 
specific crystallographic directions. 
It adds commands to convert vectors between crystallographic and cartesian coordinates 
and a simple GUI for setting the view. The GUI is largely inspired by the "Orientation" 
window of the program VESTA and the "Set View Direction" window of CrystalMaker.

Note that for the plugin to work, the active molecule must contain unit cell information.

# Installation

Put the crystallography folder in a folder searched by VMD, that is, a folder
listed in `auto_path`. For instance, you may put it in `~/vmd/plugins`, and add

    set auto_path [concat $env(HOME)/vmd/plugins $auto_path] ;

to your `~/.vmdrc` file. To add the plugin to the Plugins-menu, add the following
to your `~/.vmdrc` file (or just type it in VMD when needed):

    vmd_install_extension crystallography cryst_tk "Crystallography"

# Example usage

The GUI is opened by using the menu item or by typing `cryst_tk`.

To view along the [111] direction, say, type `view_along {1 1 1}`.

To show crystal axes (without using the GUI), type `crystal_axes on -position lower-left`, say.
Similarly, type `view_vectors on` to show the vectors of the current viewing plane. 
The plugin tries to show these as properly formatted Miller indices when a crystal plane
is in focus.

`cart2cryst` converts a cartesian coordinate vector into a crystal vector, and `cryst2cart` 
converts vice versa. See `crystallography.tcl` for more information.
