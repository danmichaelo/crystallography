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
  
  #debug "update_gui"

  # [pcc get] returns { { a b c alpha beta gamma } }
  set p [lindex [pbc get -molid $::Crystallography::currentMol] 0]
  set a [lindex $p 0]; set b [lindex $p 1]; set c [lindex $p 2];
  set alpha [lindex $p 3]; set beta [lindex $p 4]; set gamma [lindex $p 5];
  
  # Lattice parameters (formatted nicely for the GUI):
  set latticeParamText('a') [format "a = %.03f Å" $a]
  set latticeParamText('b') [format "b = %.03f Å" $b]
  set latticeParamText('c') [format "c = %.03f Å" $c]
  set latticeParamText('alpha') [format "α = %.02f°" $alpha]
  set latticeParamText('beta') [format "β = %.02f°" $beta]
  set latticeParamText('gamma') [format "γ = %.02f°" $gamma]
  
  
  # Update orientation:
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
    set molMenuButtonText "$::Crystallography::currentMol: $name"
  } else { 
    # no molecules loaded: use nullMolString
    set molMenuButtonText $::Crystallography::currentMol
  }
}

proc ::Crystallography::GUI::show_gui {} {
  variable w
  variable Crystallography_state
  variable timestep

  # If already initialized, just turn on
  debug "GUI::show_gui"
  
  if [winfo exists .crystallography] {
    debug "   window already initialized"
    wm deiconify .crystallography
    raise .crystallography
    return $w
  }

  # Initialize window

  set w [toplevel .crystallography]
  wm title $w "Crystallography Plugin"
  #wm resizable $w 0 0
  
#   label $frame.title -text "Active Clipping Planes:" -background darkgrey
 #  pack $frame.title -anchor w -expand 1 -fill x
  # pack $frame -expand 1 -fill x -padx 8 -pady 4

  # Molecule selector menu:
  frame $w.info ;# -relief solid -borderwidth 1 -background lightgrey

	  variable nullMolString "none"
	  variable molMenuButtonText  
	  variable usableMolLoaded 0
	  update_molmenubtn_text

	  label $w.info.mollabel -text "Molecule: " -justify right -font TkCaptionFont
	  pack $w.info.mollabel -side left -padx 2 -pady 2
	  menubutton $w.info.mol -textvar [namespace current]::molMenuButtonText -menu $w.info.mol.menu 
	  menu $w.info.mol.menu -tearoff no
	  fill_mol_menu $w.info.mol.menu
  	  pack $w.info.mol -side left -expand 1 -fill x
  pack $w.info -side top -fill x -padx 10 -pady 8

   #frame $w.fr
   #label $w.fr.title -text "Lattice parameters:" -background darkgrey
   #pack $w.fr.title -anchor w -expand 1 -fill x
   #pack $w.fr -expand 1 -fill x -padx 8 -pady 4


  # Lattice parameters

  labelframe $w.uc -text "Lattice parameters" 
  label $w.uc.a -textvariable ::Crystallography::GUI::latticeParamText('a')
  label $w.uc.b -textvariable ::Crystallography::GUI::latticeParamText('b')
  label $w.uc.c -textvariable ::Crystallography::GUI::latticeParamText('c')
  label $w.uc.alpha -textvariable ::Crystallography::GUI::latticeParamText('alpha')
  label $w.uc.beta -textvariable ::Crystallography::GUI::latticeParamText('beta') 
  label $w.uc.gamma -textvariable ::Crystallography::GUI::latticeParamText('gamma')

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
  
  labelframe $w.orientation -text "Current orientation";

    label $w.orientation.label_0 -text "   x: " -justify left
    grid $w.orientation.label_0 -column 0 -row 0
    label $w.orientation.label_1 -text "   y: " -justify left
    grid $w.orientation.label_1 -column 0 -row 1
    label $w.orientation.label_2 -text "   z: " -justify left
    grid $w.orientation.label_2 -column 0 -row 2
    for {set i 0} {$i < 3} {incr i} {
      for {set j 0} {$j < 3} {incr j} {
        label $w.orientation.coords_${i}_${j} -textvariable ::Crystallography::GUI::orientation_${i}_${j} -font TkFixedFont
        grid $w.orientation.coords_${i}_${j} -row $i -column [expr $j+1]
      }
    }
  pack $w.orientation -side top -fill x -padx 10 -pady 4
    
  # Axes:

  labelframe $w.draw -text "Draw"
     grid [checkbutton $w.draw.crystaxes -text "crystallographic axes" -variable [namespace current]::drawCrystAxes -anchor w] -row 0 -column 0 -sticky w 
     grid [checkbutton $w.draw.viewvectors -text "orientation vectors" -variable [namespace current]::drawViewVectors -anchor w] -row 1 -column 0 -sticky w 
  pack $w.draw -side top -fill x -padx 10 -pady 4

#  label $w.axes.label -text "Draw:" -justify left
#   frame $w.axes.dd
#   set menu [tk_optionMenu $w.axes.dd.menu Crystallography::Crystallography_state ""]
#   $menu delete 0 
#   $menu insert 0 radiobutton -label "nothing" -command {Crystallography hide}
#   $menu insert 1 radiobutton -label "crystallographic axes" -command {Crystallography show}
#   $menu insert 2 radiobutton -label "view plane vectors" -command {Crystallography show}
#   pack $w.axes.dd.menu -expand yes -fill x 
#   pack $w.axes.label $w.axes.dd -side left -expand 1 -padx 2 -pady 2
#   pack $w.axes -side top -fill x -padx 10 -pady 4
  
  # View direction
  
  labelframe $w.viewdir -text "View direction";

    frame $w.viewdir.main
      # Projection vector frame (left)
      frame $w.viewdir.main.proj
        label $w.viewdir.main.proj.label -text "Projection vector" -justify center
        frame $w.viewdir.main.proj.grid
        
        label $w.viewdir.main.proj.grid.x -text "   u: " 
        grid $w.viewdir.main.proj.grid.x -column 0 -row 0
        entry $w.viewdir.main.proj.grid.u -width 3 -textvariable ::Crystallography::GUI::projvec_0
        grid $w.viewdir.main.proj.grid.u -column 1 -row 0

        label $w.viewdir.main.proj.grid.y -text "   v: " 
        grid $w.viewdir.main.proj.grid.y -column 0 -row 1
        entry $w.viewdir.main.proj.grid.v -width 3 -textvariable ::Crystallography::GUI::projvec_1
        grid $w.viewdir.main.proj.grid.v -column 1 -row 1

        label $w.viewdir.main.proj.grid.z -text "   w: " 
        grid $w.viewdir.main.proj.grid.z -column 0 -row 2
        entry $w.viewdir.main.proj.grid.w -width 3 -textvariable ::Crystallography::GUI::projvec_2
        grid $w.viewdir.main.proj.grid.w -column 1 -row 2

      pack $w.viewdir.main.proj.label $w.viewdir.main.proj.grid -side top -padx 4 -pady 4
  
      # Upward vector frame (right)
      frame $w.viewdir.main.up
        label $w.viewdir.main.up.label -text "Upward vector" -justify center
        frame $w.viewdir.main.up.grid
        
        label $w.viewdir.main.up.grid.x -text "   h: " 
        grid $w.viewdir.main.up.grid.x -column 0 -row 0
        entry $w.viewdir.main.up.grid.h -width 3 -textvariable ::Crystallography::GUI::upvec_0
        grid $w.viewdir.main.up.grid.h -column 1 -row 0
        
        label $w.viewdir.main.up.grid.y -text "   k: " 
        grid $w.viewdir.main.up.grid.y -column 0 -row 1
        entry $w.viewdir.main.up.grid.k -width 3 -textvariable ::Crystallography::GUI::upvec_1
        grid $w.viewdir.main.up.grid.k -column 1 -row 1

        label $w.viewdir.main.up.grid.z -text "   l: " 
        grid $w.viewdir.main.up.grid.z -column 0 -row 2
        entry $w.viewdir.main.up.grid.l -width 3 -textvariable ::Crystallography::GUI::upvec_2
        grid $w.viewdir.main.up.grid.l -column 1 -row 2

      pack $w.viewdir.main.up.label $w.viewdir.main.up.grid -side top -padx 4 -pady 4
  
    pack $w.viewdir.main.proj $w.viewdir.main.up -side left -padx 4 -pady 4
    
    frame $w.viewdir.buttons
      button $w.viewdir.buttons.apply -text "Apply" -justify left -command {::Crystallography::GUI::set_view_direction}
    pack $w.viewdir.buttons.apply -side left
  
  pack $w.viewdir.main $w.viewdir.buttons -side top
    
  # Pack together
  
  pack $w.viewdir -side top -padx 10 -pady 4

  update_gui

  ######################################
  # GUI EVENTS
  
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

  trace add variable ::Crystallography::GUI::drawCrystAxes write ::Crystallography::GUI::crystaxes_onchange
  trace add variable ::Crystallography::GUI::drawViewVectors write ::Crystallography::GUI::viewvectors_onchange
  
  # When a new molecule is loaded or deleted, we update the mol menu
  trace add variable ::vmd_initialize_structure write ::Crystallography::GUI::initialize_structure_cb 
  
  # When the orientation is changed, we update the orientation frame
  trace add variable ::vmd_logfile write ::Crystallography::GUI::logfile_cb
  
}

proc ::Crystallography::GUI::crystaxes_onchange {args} {
  variable drawCrystAxes
  debug "draw cryst axes: $drawCrystAxes"
  ::Crystallography::toggleCrystAxes $drawCrystAxes    
}

proc ::Crystallography::GUI::viewvectors_onchange {args} {
  variable drawViewVectors
  debug "draw vectors: $drawViewVectors"
  ::Crystallography::toggleViewVectors $drawViewVectors  
}

proc ::Crystallography::GUI::destroy_gui {} {
  variable w
  debug "WM_DELETE_WINDOW"
  trace remove variable ::Crystallography::currentMol write ::Crystallography::GUI::update_molmenubtn_text
  trace remove variable ::Crystallography::currentMol write ::Crystallography::GUI::update_gui
  trace remove variable ::Crystallography::GUI::drawCrystAxes write ::Crystallography::GUI::crystaxes_onchange
  trace remove variable ::Crystallography::GUI::drawViewVectors write ::Crystallography::GUI::viewvectors_onchange
  trace remove variable ::vmd_initialize_structure write ::Crystallography::GUI::initialize_structure_cb 
  trace remove variable ::vmd_logfile write ::Crystallography::GUI::logfile_cb
  destroy $w
}

proc ::Crystallography::GUI::initialize_structure_cb { args } {
  variable w
  fill_mol_menu $w.info.mol.menu
}

proc ::Crystallography::GUI::logfile_cb { args } {

  # Check for display transforms
  if {[string match "rotate *" $::vmd_logfile] || [string match "translate *" $::vmd_logfile]} { 
    update_gui
  } elseif {[string match "scale *" $::vmd_logfile] || [string match "mol top *" $::vmd_logfile]} {
    update_gui
  } elseif {[string match "display *" $::vmd_logfile]} {
    update_gui
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
      lappend molList $mm
      $name add radiobutton -variable ::Crystallography::currentMol \
        -value $mm -label "$mm [molinfo $mm get name]"
    }
  }

  #set if any non-Graphics molecule is loaded
  if {[lsearch -exact $molList $currentMol] == -1} {
    if {[lsearch -exact $molList [molinfo top]] != -1} {
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
