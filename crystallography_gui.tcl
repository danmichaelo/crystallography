#
# crystallography_gui.tcl : Crystallography VMD plugin GUI
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
# For the plugin to work, the loaded molecule must contain unit cell information.
#
# Author: Dan Michael Heggø
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
    set projAlong "uvw"

	set labelProj1 "   u: "
	set labelProj2 "   v: "
	set labelProj3 "   w: "
	set labelUp1 "   h: "
	set labelUp2 "   k: "
	set labelUp3 "   l: "

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
    variable projAlong

    if {$projvec_0 == ""} { set projvec_0 0 }
    if {$projvec_1 == ""} { set projvec_1 0 }
    if {$projvec_2 == ""} { set projvec_2 0 }
    if {$upvec_0 == ""} { set upvec_0 0 }
    if {$upvec_1 == ""} { set upvec_1 0 }
    if {$upvec_2 == ""} { set upvec_2 0 }
    
    # TODO: Perhaps test for non-numerics...

    set projvec [list $projvec_0 $projvec_1 $projvec_2]
    set upvec [list $upvec_0 $upvec_1 $upvec_2]

    ::Crystallography::set_view_direction $projvec -upvec $upvec -projalong "$projAlong"
    
    # Update vectors in case of scaling or orthogonalization
    
    if {"$projAlong" == "uvw"} {
        set projvec [::Crystallography::get_view_vector "z" "dir"]
        set upvec [::Crystallography::get_view_vector "y" "rec"]
	} else {
        set projvec [::Crystallography::get_view_vector "z" "rec"]
        set upvec [::Crystallography::get_view_vector "y" "dir"]	
	}

    set projvec_0 [lindex $projvec 0]
    set projvec_1 [lindex $projvec 1]
    set projvec_2 [lindex $projvec 2]

    set upvec_0 [lindex $upvec 0]
    set upvec_1 [lindex $upvec 1]
    set upvec_2 [lindex $upvec 2]
}  

proc ::Crystallography::GUI::update_gui_projalong {args} {

    variable projAlong
    variable labelProj1
    variable labelProj2
    variable labelProj3
    variable labelUp1
    variable labelUp2
    variable labelUp3

    # If GUI not initialized, go away
    if { ! [ winfo exists .crystallography]} return
    
    if { "$projAlong" == "uvw" } {
		set labelProj1 "   u: "
		set labelProj2 "   v: "
		set labelProj3 "   w: "
		set labelUp1 "   h: "
		set labelUp2 "   k: "
		set labelUp3 "   l: "
    } else {
		set labelProj1 "   h: "
		set labelProj2 "   k: "
		set labelProj3 "   l: "
		set labelUp1 "   u: "
		set labelUp2 "   v: "
		set labelUp3 "   w: "
	}

}

proc ::Crystallography::GUI::update_gui {args} {

    variable latticeParamText
    variable w

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
                set orientation_${i}_${j}       
            }
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
        $w.viewdir.buttons.apply state disabled
        $w.quickview.buttons.a state disabled
        $w.quickview.buttons.b state disabled
        $w.quickview.buttons.c state disabled
        $w.quickview.buttons.aa state disabled
        $w.quickview.buttons.bb state disabled
        $w.quickview.buttons.cc state disabled
        
    } else {
        set a [lindex $p 0]; set b [lindex $p 1]; set c [lindex $p 2];
        set alpha [lindex $p 3]; set beta [lindex $p 4]; set gamma [lindex $p 5];
        set latticeParamText('a') [format "a = %.03f Å" $a]
        set latticeParamText('b') [format "b = %.03f Å" $b]
        set latticeParamText('c') [format "c = %.03f Å" $c]
        set latticeParamText('alpha') [format "α = %.02f°" $alpha]
        set latticeParamText('beta') [format "β = %.02f°" $beta]
        set latticeParamText('gamma') [format "γ = %.02f°" $gamma]
        $w.viewdir.buttons.apply state !disabled
        $w.quickview.buttons.a state !disabled
        $w.quickview.buttons.b state !disabled
        $w.quickview.buttons.c state !disabled
        $w.quickview.buttons.aa state !disabled
        $w.quickview.buttons.bb state !disabled
        $w.quickview.buttons.cc state !disabled
    }

    # Update orientation (formatted for the GUI)
    set rot [molinfo $::Crystallography::currentMol get rotate_matrix]
    for {set i 0} {$i < 3} {incr i} {
        for {set j 0} {$j < 3} {incr j} {
            variable orientation_${i}_${j}
            set orientation_${i}_${j} [format "%+1.3f" [lindex $rot 0 $i $j] ]
        }
    }

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

    ttk::labelframe $w.uc -text "Current lattice parameters:" 
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

    ttk::labelframe $w.orientation -text "Current orientation:";

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

    ttk::labelframe $w.draw -text "Draw:"
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

    ttk::labelframe $w.viewdir -text "Set view direction:";

    ttk::frame $w.viewdir.main
    # Projection vector frame (left)

    ttk::frame $w.viewdir.main.opt
    ttk::radiobutton $w.viewdir.main.opt.rb1 -text "Project along axis \[uvw\]" -variable ::Crystallography::GUI::projAlong -value "uvw" 
    ttk::radiobutton $w.viewdir.main.opt.rb2 -text "Project along the normal to the plane (hkl)" -variable ::Crystallography::GUI::projAlong -value "hkl"
    grid $w.viewdir.main.opt.rb1 -column 0 -row 0 -sticky w
    grid $w.viewdir.main.opt.rb2 -column 0 -row 1 -sticky w
    pack $w.viewdir.main.opt -side top -padx 4 -pady 4
    
    ttk::frame $w.viewdir.main.vec
    
    ttk::label $w.viewdir.main.vec.projlabel -text "Projection vector (z):" 
    grid $w.viewdir.main.vec.projlabel -column 0 -row 0 -sticky w 
	
    ttk::label $w.viewdir.main.vec.ul -textvariable ::Crystallography::GUI::labelProj1 
    grid $w.viewdir.main.vec.ul -column 1 -row 0
    ttk::entry $w.viewdir.main.vec.u -width 3 -textvariable ::Crystallography::GUI::projvec_0
    grid $w.viewdir.main.vec.u -column 2 -row 0

    ttk::label $w.viewdir.main.vec.vl -textvariable ::Crystallography::GUI::labelProj2
    grid $w.viewdir.main.vec.vl -column 3 -row 0
    ttk::entry $w.viewdir.main.vec.v -width 3 -textvariable ::Crystallography::GUI::projvec_1
    grid $w.viewdir.main.vec.v -column 4 -row 0

    ttk::label $w.viewdir.main.vec.wl -textvariable ::Crystallography::GUI::labelProj3
    grid $w.viewdir.main.vec.wl -column 5 -row 0
    ttk::entry $w.viewdir.main.vec.w -width 3 -textvariable ::Crystallography::GUI::projvec_2
    grid $w.viewdir.main.vec.w -column 6 -row 0

    ttk::label $w.viewdir.main.vec.uplabel -text "Upward vector (y):" 
    grid $w.viewdir.main.vec.uplabel -column 0 -row 1 -sticky w 

    ttk::label $w.viewdir.main.vec.hl -textvariable ::Crystallography::GUI::labelUp1
    grid $w.viewdir.main.vec.hl -column 1 -row 1
    ttk::entry $w.viewdir.main.vec.h -width 3 -textvariable ::Crystallography::GUI::upvec_0
    grid $w.viewdir.main.vec.h -column 2 -row 1

    ttk::label $w.viewdir.main.vec.kl -textvariable ::Crystallography::GUI::labelUp2
    grid $w.viewdir.main.vec.kl -column 3 -row 1
    ttk::entry $w.viewdir.main.vec.k -width 3 -textvariable ::Crystallography::GUI::upvec_1
    grid $w.viewdir.main.vec.k -column 4 -row 1

    ttk::label $w.viewdir.main.vec.ll -textvariable ::Crystallography::GUI::labelUp3 
    grid $w.viewdir.main.vec.ll -column 5 -row 1
    ttk::entry $w.viewdir.main.vec.l -width 3 -textvariable ::Crystallography::GUI::upvec_2
    grid $w.viewdir.main.vec.l -column 6 -row 1

    pack $w.viewdir.main.vec -side top -padx 4 -pady 4

    ttk::frame $w.viewdir.buttons
    ttk::button $w.viewdir.buttons.apply -text "Apply" -command {::Crystallography::GUI::set_view_direction}
    pack $w.viewdir.buttons.apply -side left

    pack $w.viewdir.main $w.viewdir.buttons -side top 

    # Pack together

    pack $w.viewdir -side top -fill x -padx 10 -pady 4

    ttk::labelframe $w.quickview -text "View presets:";
    ttk::frame $w.quickview.buttons
    ttk::button $w.quickview.buttons.a -text "a" -command {::Crystallography::GUI::set_view_from_preset "a"}
    ttk::button $w.quickview.buttons.b -text "b" -command {::Crystallography::GUI::set_view_from_preset "b"}
    ttk::button $w.quickview.buttons.c -text "c" -command {::Crystallography::GUI::set_view_from_preset "c"}
    ttk::button $w.quickview.buttons.aa -text "a*" -command {::Crystallography::GUI::set_view_from_preset "a*"}
    ttk::button $w.quickview.buttons.bb -text "b*" -command {::Crystallography::GUI::set_view_from_preset "b*"}
    ttk::button $w.quickview.buttons.cc -text "c*" -command {::Crystallography::GUI::set_view_from_preset "c*"}
    grid $w.quickview.buttons.a -column 0 -row 0
    grid $w.quickview.buttons.b -column 1 -row 0
    grid $w.quickview.buttons.c -column 2 -row 0
    grid $w.quickview.buttons.aa -column 0 -row 1
    grid $w.quickview.buttons.bb -column 1 -row 1
    grid $w.quickview.buttons.cc -column 2 -row 1
    pack $w.quickview.buttons -side top -fill x -padx 10 -pady 4
    pack $w.quickview -side top -fill x -padx 10 -pady 4
    
    ttk::label $w.footer -text "Tip: Type 'cryst' in console for command line usage" -font TkSmallCaptionFont -foreground "dark slate gray"
    pack $w.footer -side top -fill x -padx 10 -pady 4

    update_gui

    ######################################
    # Subscribe to some events (remember to unsubscribe to all upon destroy_gui below)

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

    # When projection along is changed
    trace add variable ::Crystallography::GUI::projAlong write ::Crystallography::GUI::update_gui_projalong

    # When a new molecule is loaded or deleted, we update the mol menu
    trace add variable ::vmd_initialize_structure write ::Crystallography::GUI::initialize_structure_cb 

    # When the orientation is changed, we update the orientation frame
    trace add variable ::vmd_logfile write ::Crystallography::GUI::logfile_cb
    
    return $w
}

proc ::Crystallography::GUI::set_view_from_preset {preset} {
    variable projvec_0
    variable projvec_1
    variable projvec_2
    variable upvec_0
    variable upvec_1
    variable upvec_2
    variable projAlong
    
    switch -- $preset {
        "a"  { set projAlong "uvw"
               set projvec_0 1; set projvec_1 0; set projvec_2 0
               set upvec_0 0; set upvec_1 0; set upvec_2 1
             }
        "b"  { set projAlong "uvw"
               set projvec_0 0; set projvec_1 1; set projvec_2 0
               set upvec_0 1; set upvec_1 0; set upvec_2 0
             }
        "c"  { set projAlong "uvw"
               set projvec_0 0; set projvec_1 0; set projvec_2 1
               set upvec_0 0; set upvec_1 1; set upvec_2 0
            }
        "a*" { set projAlong "hkl"
               set projvec_0 1; set projvec_1 0; set projvec_2 0
               set upvec_0 0; set upvec_1 0; set upvec_2 1
             }
        "b*" { set projAlong "hkl"
               set projvec_0 0; set projvec_1 1; set projvec_2 0
               set upvec_0 1; set upvec_1 0; set upvec_2 0
             }
        "c*" { set projAlong "hkl"
               set projvec_0 0; set projvec_1 0; set projvec_2 1
               set upvec_0 0; set upvec_1 1; set upvec_2 0
             }
    }
    set_view_direction
}

proc ::Crystallography::GUI::destroy_gui {} {
    variable w
    debug "WM_DELETE_WINDOW"
    trace remove variable ::Crystallography::currentMol write ::Crystallography::GUI::update_molmenubtn_text
    trace remove variable ::Crystallography::currentMol write ::Crystallography::GUI::update_gui
    trace remove variable ::Crystallography::GUI::projAlong write ::Crystallography::GUI::update_gui_projalong
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
