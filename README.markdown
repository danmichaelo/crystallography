# About

[VMD](http://www.ks.uiuc.edu/Research/vmd/) plugin written primarily to make it 
easier to align the view direction along specific crystallographic directions. 
It also includes commands to convert vectors between crystallographic and cartesian 
coordinates, and to draw arrows indicating the crystallographic axes arrows and/or 
the current view direction.

The plugin can be used either from the command line or from a GUI, inspired in part
by the "Orientation" window of the program VESTA and the "Set View Direction" window 
of CrystalMaker.

For the plugin to work, the loaded molecule must contain unit cell information.
If VMD can not read this from your file, it can be set manually using the 
pbctools plugin. Note that pbctools also provide the nice command `pbc box' to draw
the unit cell.

# Installation

Put the crystallography folder in a folder searched by VMD, that is, a folder
listed in `auto_path`. For instance, you may put it in `~/vmd/plugins`, and add

    set auto_path [concat $env(HOME)/vmd/plugins $auto_path] ;

to your `~/.vmdrc` file. To add the plugin to the Plugins-menu, add the following
to your `~/.vmdrc` file (or just type it in VMD when needed):

    vmd_install_extension crystallography cryst_tk "Crystallography"

# Example usage

To view along the [111] direction, type `view_along {1 1 1}` (list notation) or `view_along 111` (short-hand notation)
To view towards the (100) plane, type `view_towards {1 0 0}` or `view_towards 100`.
To show crystal axes, type `crystal_axes on -position lower-left`, say. 
Similarly, type `view_vectors on` to show the vectors of the current viewing plane. 
The plugin tries to show these as properly formatted Miller indices when a crystal plane is in focus.

The commands `cart2dir` and `cart2rec` transforms a vector from a cartesian basis {**i**,**j**,**k**} to a 
real space lattice basis {**a**,**b**,**c**} and a reciprocal space lattice basis {**a**\*,**b**\*,**c**\*}, respectively. 
And `dir2cart` and `rec2cart` transforms the other way around. 

All the above can also be carried out using the GUI, that can be opened by using the menu item or by typing `cryst_tk`.

See `crystallography.tcl` for more information.

# GUI

![GUI on Mac OS X](gui_mac.png)

