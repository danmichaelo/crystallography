#############################################################################################
#
# Crystallography VMD plugin
#
# Author: Dan Michael Heggø
#
# This plugin was written to make it easier to project the view direction along 
# crystallographic directions. 
# It adds commands to convert vectors between crystallographic and cartesian coordinates 
# and a simple GUI for setting the view. The GUI is largely inspired by the "Orientation" 
# window of the program VESTA and the "Set View Direction" window of CrystalMaker.
# 
# This plugin makes use of Tile/Ttk, a styles and theming widget collection which can replace 
# most of the widgets in Tk with variants which are truly platform native through calls to an
# operating system's API. Themes covered in this way are Windows XP, Windows Classic, 
# Qt (which hooks into the X11 KDE environment libraries) and Aqua (Mac OS X).
# http://wiki.tcl.tk/11075
#
# Note that for the plugin to work, the loaded molecule must contain unit cell information.
# 
# usage: cryst
# GUI: cryst_tk
# 
# Add to menu:
# menu tk register "Crystallography" cryst_tk
# or
# vmd_install_extension cryst cryst_tk "Crystallography"
#

# Opens the GUI
proc cryst_tk {} {
  ::Crystallography::update
  return [Crystallography::GUI::show_gui]
}

# ttk::optionmenu --
# by Mats Bengtsson ( matben ) - 2005-04-23 16:47:12 CES
#
# This procedure creates an option button named $w and an associated
# menu. Together they provide the functionality of Motif option menus:
# they can be used to select one of many values, and the current value
# appears in the global variable varName, as well as in the text of
# the option menubutton. The name of the menu is returned as the
# procedure's result, so that the caller can use it to change configuration
# options on the menu or otherwise manipulate it.
#
# Arguments:
# w - The name to use for the menubutton.
# varName - Global variable to hold the currently selected value.
# firstValue - First of legal values for option (must be >= 1).
# args - Any number of additional values.

proc ttk::optionmenu {w varName firstValue args} {
  #upvar #0 $varName var
  #if {![info exists var]} {
  #  set var $firstValue
  #}
  ttk::menubutton $w -menu $w.menu -direction flush -textvariable $varName
  menu $w.menu -tearoff 0
  $w.menu add radiobutton -label $firstValue -variable $varName
  foreach i $args {
    $w.menu add radiobutton -label $i -variable $varName
  }
  return $w.menu
}


#############################################################################################
#                                      GUI "class"
#############################################################################################

package provide crystallography_gui 1.0

namespace eval ::Crystallography::GUI:: {

  package require crystallography 1.0
  
  # Lattice parameters (formatted nicely for the GUI):
  array set latticeParamText {a - b - c - alpha - beta - gamma -}  ;# a,b,c,alpha,beta,gamma 	
  
  # Current orientation:
  for {set i 0} {$i < 3} {incr i} {
	for {set j 0} {$j < 3} {incr j} {
	  set orientation_${i}_${j} "-"
	}
  }
  
  # input variables:
  set projvec_0 0
  set projvec_1 0
  set projvec_2 1
  set upvec_0 0
  set upvec_1 1
  set upvec_2 0
  
  set molMenuButtonText "none"
  
  #gui
  variable w                                          ;# handle to main window
  
}

proc ::Crystallography::GUI::debug {str} {
  ::Crystallography::debug $str
}

proc ::Crystallography::GUI::set_view_direction { } {
  variable projvec_0
  variable projvec_1
  variable projvec_2
  variable upvec_0
  variable upvec_1
  variable upvec_2
  
  set projvec [list $projvec_0 $projvec_1 $projvec_2]
  set upvec [list $upvec_0 $upvec_1 $upvec_2]
 
  ::Crystallography::set_view_direction $projvec $upvec

}  

proc ::Crystallography::GUI::update_gui {args} {
  
  variable latticeParamText

  # If GUI not initialized, go away
  if { ! [ winfo exists .crystallography]} return

  # If a molecule hasn't been selected, go away
  if { [catch { molinfo $::Crystallography::currentMol get id } ] } {
    debug "No molecule loaded"
    set latticeParamText('a') "-"
    set latticeParamText('b') "-" 
    set latticeParamText('c') "-" 
    set latticeParamText('alpha') "-"
    set latticeParamText('beta') "-"
    set latticeParamText('gamma') "-"
    for {set i 0} {$i < 3} {incr i} {
      for {set j 0} {$j < 3} {incr j} {
        variable orientation_${i}_${j}
        set orientation_${i}_${j}       }
    }
    return
  }
  
  #debug "update_gui"

  # Lattice parameters (formatted nicely for the GUI):
  set p [ lindex [ pbc get -molid $::Crystallography::currentMol ] 0] 
  if {"[lindex $p 0]" == "0"} {
    set latticeParamText('a') "unit cell data missing"
    set latticeParamText('b') ""
    set latticeParamText('c') ""
    set latticeParamText('alpha') ""
    set latticeParamText('beta') ""
    set latticeParamText('gamma') ""
  } else {
    set a [lindex $p 0]; set b [lindex $p 1]; set c [lindex $p 2];
    set alpha [lindex $p 3]; set beta [lindex $p 4]; set gamma [lindex $p 5];
    set latticeParamText('a') [format "a = %.03f Å" $a]
    set latticeParamText('b') [format "b = %.03f Å" $b]
    set latticeParamText('c') [format "c = %.03f Å" $c]
    set latticeParamText('alpha') [format "α = %.02f°" $alpha]
    set latticeParamText('beta') [format "β = %.02f°" $beta]
    set latticeParamText('gamma') [format "γ = %.02f°" $gamma]
  }
  
  # Update orientation (formatted for the GUI)
  set rot [molinfo $::Crystallography::currentMol get rotate_matrix]
  for {set i 0} {$i < 3} {incr i} {
    for {set j 0} {$j < 3} {incr j} {
      variable orientation_${i}_${j}
      set orientation_${i}_${j} [format "%+1.3f" [lindex $rot 0 $i $j] ]
    }
  }
  
  #
  # TODO:
  # Update projvec and upvec
  #
  #
  #
  #
  #
  
}

proc ::Crystallography::GUI::update_molmenubtn_text {args} {
  variable molMenuButtonText
  debug "GUI::update_molmenubtn_text"
  #puts $args
  if { ! [catch { molinfo $::Crystallography::currentMol get name } name ] } {
    set molMenuButtonText "$::Crystallography::currentMol: [lindex $name 0]"
  } else { 
    # no molecules loaded: use nullMolString
    set molMenuButtonText $::Crystallography::currentMol
  }
}

# Tk reference: http://www.tcl.tk/man/tcl/TkCmd/contents.htm
proc ::Crystallography::GUI::show_gui {} {
  variable w
  variable Crystallography_state
  variable timestep

  debug "GUI::show_gui"

  # Check if window is already initialized
  
  if [winfo exists .crystallography] {
    debug "   window already initialized"
    wm deiconify .crystallography
    raise .crystallography              ;# bring to front
    return $w                           ;# and return the window instance
  }

  # Initialize window

  set w [::toplevel .crystallography]
  # since there are no ttk::toplevel method (why not?) See http://wiki.tcl.tk/11075
  place [ttk::frame $w.tilebg] -x 0 -y 0 -relwidth 1 -relheight 1   

  wm title $w "Crystallography Plugin"
  wm resizable $w 1 0                     ;# allow resize width only (in case of long mol names)
  
  # Molecule selector menu

  ttk::frame $w.info

	  variable nullMolString "none"
	  variable molMenuButtonText  
	  variable usableMolLoaded 0
	  update_molmenubtn_text

	  ttk::label $w.info.mollabel -text "Molecule: " -font TkCaptionFont
	  pack $w.info.mollabel -side left -padx 2 -pady 2
	  ttk::menubutton $w.info.mol -textvar [namespace current]::molMenuButtonText -menu $w.info.mol.menu 
	  menu $w.info.mol.menu -tearoff no
	  fill_mol_menu $w.info.mol.menu
  	  pack $w.info.mol -side left -expand 1 -fill x
  pack $w.info -side top -fill x -padx 10 -pady 8

  # Lattice parameters

  ttk::labelframe $w.uc -text "Lattice parameters" 
  ttk::label $w.uc.a -textvariable ::Crystallography::GUI::latticeParamText('a')
  ttk::label $w.uc.b -textvariable ::Crystallography::GUI::latticeParamText('b')
  ttk::label $w.uc.c -textvariable ::Crystallography::GUI::latticeParamText('c')
  ttk::label $w.uc.alpha -textvariable ::Crystallography::GUI::latticeParamText('alpha')
  ttk::label $w.uc.beta -textvariable ::Crystallography::GUI::latticeParamText('beta') 
  ttk::label $w.uc.gamma -textvariable ::Crystallography::GUI::latticeParamText('gamma')

  grid $w.uc.a -column 0 -row 0 -sticky w
  grid $w.uc.b -column 1 -row 0 -sticky w
  grid $w.uc.c -column 2 -row 0 -sticky w

  grid $w.uc.alpha -column 0 -row 1 -sticky w
  grid $w.uc.beta -column 1 -row 1 -sticky w
  grid $w.uc.gamma -column 2 -row 1 -sticky w
  grid columnconfigure $w.uc 0 -weight 1
  grid columnconfigure $w.uc 1 -weight 1
  grid columnconfigure $w.uc 2 -weight 1
  pack $w.uc -side top -fill x -padx 10 -pady 4

  # Current orientation
  
  ttk::labelframe $w.orientation -text "Current orientation";

    ttk::label $w.orientation.label_0 -text "   x: " -justify left
    grid $w.orientation.label_0 -column 0 -row 0
    ttk::label $w.orientation.label_1 -text "   y: " -justify left
    grid $w.orientation.label_1 -column 0 -row 1
    ttk::label $w.orientation.label_2 -text "   z: " -justify left
    grid $w.orientation.label_2 -column 0 -row 2
    for {set i 0} {$i < 3} {incr i} {
      for {set j 0} {$j < 3} {incr j} {
        ttk::label $w.orientation.coords_${i}_${j} -textvariable ::Crystallography::GUI::orientation_${i}_${j} -font TkFixedFont
        grid $w.orientation.coords_${i}_${j} -row $i -column [expr $j+1]
      }
    }
  pack $w.orientation -side top -fill x -padx 10 -pady 4
    
  # Axes

  ttk::labelframe $w.draw -text "Draw"
    ttk::checkbutton $w.draw.crystaxes -text "crystallographic axes" -variable ::Crystallography::drawCrystAxes 
    grid $w.draw.crystaxes -row 0 -column 0 -columnspan 3 -sticky w 

    ttk::optionmenu $w.draw.crystaxesloc ::Crystallography::crystAxesLoc "lower left" "upper left" "lower right" "upper right"
    grid $w.draw.crystaxesloc -row 0 -column 3 -sticky we

    grid [ttk::label $w.draw.space0 -text "    "] -row 1 -column 0 -sticky w 
    grid [ttk::label $w.draw.crystaxeslabel -text "Scale:"] -row 1 -column 1 -sticky ws
    grid [ttk::scale $w.draw.crystaxesscale -orient horizontal -length 100 -from 50.0 -to 150.0 -variable ::Crystallography::crystAxesScale] -row 1 -column 2 

    ttk::checkbutton $w.draw.viewvectors -text "orientation vectors" -variable ::Crystallography::drawViewVectors
    grid $w.draw.viewvectors -row 2 -column 0 -columnspan 3 -sticky w 

    ttk::optionmenu $w.draw.viewvectorsloc ::Crystallography::viewVectorsLoc "lower left" "upper left" "lower right" "upper right"
    grid $w.draw.viewvectorsloc -row 2 -column 3 -sticky we
    
    grid [ttk::label $w.draw.space1 -text "    "] -row 3 -column 0 -sticky w 
    grid [ttk::label $w.draw.viewveclabel -text "Scale:"] -row 3 -column 1 -sticky ws
    grid [ttk::scale $w.draw.viewvecscale -orient horizontal -length 100 -from 50.0 -to 150.0 -variable ::Crystallography::viewVectorsScale] -row 3 -column 2 

    grid columnconfigure $w.draw 3 -weight 1 -minsize 15

  pack $w.draw -side top -fill x -padx 10 -pady 4

  # View direction
  
  ttk::labelframe $w.viewdir -text "View direction";

    ttk::frame $w.viewdir.main
      # Projection vector frame (left)
      ttk::frame $w.viewdir.main.proj
        ttk::label $w.viewdir.main.proj.label -text "Projection vector" 
        ttk::frame $w.viewdir.main.proj.grid
        
        ttk::label $w.viewdir.main.proj.grid.x -text "   u: " 
        grid $w.viewdir.main.proj.grid.x -column 0 -row 0
        ttk::entry $w.viewdir.main.proj.grid.u -width 3 -textvariable ::Crystallography::GUI::projvec_0
        grid $w.viewdir.main.proj.grid.u -column 1 -row 0

        ttk::label $w.viewdir.main.proj.grid.y -text "   v: " 
        grid $w.viewdir.main.proj.grid.y -column 0 -row 1
        ttk::entry $w.viewdir.main.proj.grid.v -width 3 -textvariable ::Crystallography::GUI::projvec_1
        grid $w.viewdir.main.proj.grid.v -column 1 -row 1

        ttk::label $w.viewdir.main.proj.grid.z -text "   w: " 
        grid $w.viewdir.main.proj.grid.z -column 0 -row 2
        ttk::entry $w.viewdir.main.proj.grid.w -width 3 -textvariable ::Crystallography::GUI::projvec_2
        grid $w.viewdir.main.proj.grid.w -column 1 -row 2

      pack $w.viewdir.main.proj.label $w.viewdir.main.proj.grid -side top -padx 4 -pady 4
  
      # Upward vector frame (right)
      ttk::frame $w.viewdir.main.up
        ttk::label $w.viewdir.main.up.label -text "Upward vector" 
        ttk::frame $w.viewdir.main.up.grid
        
        ttk::label $w.viewdir.main.up.grid.x -text "   h: " 
        grid $w.viewdir.main.up.grid.x -column 0 -row 0
        ttk::entry $w.viewdir.main.up.grid.h -width 3 -textvariable ::Crystallography::GUI::upvec_0
        grid $w.viewdir.main.up.grid.h -column 1 -row 0
        
        ttk::label $w.viewdir.main.up.grid.y -text "   k: " 
        grid $w.viewdir.main.up.grid.y -column 0 -row 1
        ttk::entry $w.viewdir.main.up.grid.k -width 3 -textvariable ::Crystallography::GUI::upvec_1
        grid $w.viewdir.main.up.grid.k -column 1 -row 1

        ttk::label $w.viewdir.main.up.grid.z -text "   l: " 
        grid $w.viewdir.main.up.grid.z -column 0 -row 2
        ttk::entry $w.viewdir.main.up.grid.l -width 3 -textvariable ::Crystallography::GUI::upvec_2
        grid $w.viewdir.main.up.grid.l -column 1 -row 2

      pack $w.viewdir.main.up.label $w.viewdir.main.up.grid -side top -padx 4 -pady 4
  
    pack $w.viewdir.main.proj $w.viewdir.main.up -side left -padx 4 -pady 4
    
    ttk::frame $w.viewdir.buttons
      ttk::button $w.viewdir.buttons.apply -text "Apply" -command {::Crystallography::GUI::set_view_direction}
    pack $w.viewdir.buttons.apply -side left
  
  pack $w.viewdir.main $w.viewdir.buttons -side top
    
  # Pack together
  
  pack $w.viewdir -side top -padx 10 -pady 4

  update_gui

  ######################################
  # Subscribe to some events 
  
  # When the window is closed:
  wm protocol $w WM_DELETE_WINDOW {::Crystallography::GUI::destroy_gui}

  # When <Enter> is pressed, we set the view direction
  bind $w <Return> {::Crystallography::GUI::set_view_direction}
  
  # When <Esc> is pressed, we close the window
  bind $w <Escape> {::Crystallography::GUI::destroy_gui}

  # When a new molecule is selected, we update the mol menu button caption...
  trace add variable ::Crystallography::currentMol write ::Crystallography::GUI::update_molmenubtn_text
  # ... and the lattice parameters
  trace add variable ::Crystallography::currentMol write ::Crystallography::GUI::update_gui

  # When a new molecule is loaded or deleted, we update the mol menu
  trace add variable ::vmd_initialize_structure write ::Crystallography::GUI::initialize_structure_cb 
  
  # When the orientation is changed, we update the orientation frame
  trace add variable ::vmd_logfile write ::Crystallography::GUI::logfile_cb
  
  return $w
}


proc ::Crystallography::GUI::destroy_gui {} {
  variable w
  debug "WM_DELETE_WINDOW"
  trace remove variable ::Crystallography::currentMol write ::Crystallography::GUI::update_molmenubtn_text
  trace remove variable ::Crystallography::currentMol write ::Crystallography::GUI::update_gui
  trace remove variable ::vmd_initialize_structure write ::Crystallography::GUI::initialize_structure_cb 
  trace remove variable ::vmd_logfile write ::Crystallography::GUI::logfile_cb
  destroy $w
}

proc ::Crystallography::GUI::initialize_structure_cb { args } {
  variable w
  ::Crystallography::debug "GUI: initialize_structure"
  fill_mol_menu $w.info.mol.menu
}

proc ::Crystallography::GUI::logfile_cb { args } {
  variable w

  # Check for display transforms
  if {[string match "rotate *" $::vmd_logfile] || [string match "translate *" $::vmd_logfile]} { 
    update_gui
  } elseif {[string match "scale *" $::vmd_logfile] || [string match "mol top *" $::vmd_logfile]} {
    update_gui
  } elseif {[string match "display *" $::vmd_logfile]} {
    update_gui
  } elseif {[string match "mol *" $::vmd_logfile]} {   ;# such as mol rename
    fill_mol_menu $w.info.mol.menu
    update_molmenubtn_text
  } 
}


# Adapted from pmepot gui
proc ::Crystallography::GUI::fill_mol_menu {name} {

  variable usableMolLoaded
  variable nullMolString

  set currentMol $::Crystallography::currentMol
  $name delete 0 end

  set molList ""
  foreach mm [array names ::vmd_initialize_structure] {
    if { $::vmd_initialize_structure($mm) != 0} {
      if {[molinfo $mm get numatoms] > 0 } {
        lappend molList $mm
        $name add radiobutton -variable ::Crystallography::currentMol \
          -value $mm -label "$mm: [lindex [molinfo $mm get name] 0]"
      }
    }
  }

  #set if any non-Graphics molecule is loaded
  if {[lsearch -exact $molList $currentMol] == -1} {
    if {[lsearch -exact $molList [molinfo top]] != -1} {
        ::Crystallography::debug "Auto-setting current mol to top molecule"
      set ::Crystallography::currentMol [molinfo top]
      set usableMolLoaded 1
    } else {
      set ::Crystallography::currentMol $nullMolString
      set usableMolLoaded 0
    }
  }

}

#############################################################################################
#                       end of the known universe for this plugin
