//==========================================================================================
//  PruneStack Plugin for MuseScore 4.4.x or higher
//  This script Copyright (C) 2016-2024 Rob Birdwell/BirdwellMusic LLC and BirdwellMusic.com
//  Full credit to the MuseScore team and all numerous other plugin developers.
//  Portions of this script were adapted from the colornotes.qml, walk.qml and
//  other scripts by Werner Schweer, et al.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License version 2
//  as published by the Free Software Foundation and appearing in
//  the file LICENCE.GPL
//===========================================================================================
import QtQuick
import QtQuick.Controls
import MuseScore

MuseScore {
	version: "1.5"
	title: "Prune Stack"
	description: "Selectively prune notes from a chord based on their vertical stack level in the chord."
	pluginType: "dialog"
	categoryCode: "composing-arranging-tools"
	thumbnailName: "prunestack.png"
	
	width: 400
	height: 240

	function getAllChordsInRange(chordArray) {

		var cursor = curScore.newCursor();
		cursor.rewind(1);
		var startStaff;
		var endStaff;
		var endTick;

		if (!cursor.segment) { // no selection
			console.log("Hey there, you must select a region of notes on a single staff.");
			return;
		}

		startStaff = cursor.staffIdx;
		cursor.rewind(2);
		if (cursor.tick == 0) {
			// this happens when the selection includes
			// the last measure of the score.
			// rewind(2) goes behind the last segment (where
			// there's none) and sets tick=0
			endTick = curScore.lastSegment.tick + 1;
		} else {
			endTick = cursor.tick;
		}

		endStaff = cursor.staffIdx;

		if (startStaff != endStaff) {
			console.log("Hey there, you must select a single staff only!");
			return;
		}

		for (var staff = startStaff; staff <= endStaff; staff++) {
			for (var voice = 0; voice < 4; voice++) {
				cursor.rewind(1); // sets voice to 0
				cursor.voice = voice; //voice has to be set after goTo
				cursor.staffIdx = staff;

				while (cursor.segment && (cursor.tick < endTick)) {
					if (cursor.element && cursor.element.type == Element.CHORD) {
						var graceChords = cursor.element.graceNotes;
						for (var i = 0; i < graceChords.length; i++) {
							chordArray.push(graceChords[i]);
						}

						// the chord of the notes...
						chordArray.push(cursor.element);

					}
					cursor.next();
				}
			}
		}
	}


	function displayMessageDlg(msg) {
		ctrlMessageDialog.text = qsTr(msg);
		ctrlMessageDialog.visible = true;
	}

	function moveToVoice() {
		console.log("Starting moveToVoice()");

		// New for 3.x - this functionality
		// is sort of odd, but currently works like this:
		// 1. Prune the stack first
		// 2. Move remaining notes to the desired layer.
		// This is at least slightly more useful than
		// the 2.x version of this script, giving the 
		// user a way to selectively move N number of
		// notes to a new layer...the pruning may even 
		// be of use...

		// FUTURE: would prefer if we could NOT
		// prune, but rather move the notes
		// in the stack level to the desired new layer.
		// But that would require that we set the 
		// notes not in the selected chord level(s) to no
		// longer be selected and currently the "selected"
		// property of a Note (or any Element) is read only.

		var wereNotesMoved = false;

		if (pruneStack()) {

			curScore.startCmd(); // Start collecting undo info.
			
			/////////////////////////////////////////////////////////////
			// we must re-select the remaining chords in the selected segment...
			var chords = new Array();
			getAllChordsInRange(chords);
			
			for (var c = 0; c < chords.length; c++) {
				  var notesInChord = chords[c].notes.length;

				  for (var n = 0; n < chords[c].notes.length; n++) {
						// TODO: need something like this, but it doesn't exist ??
						// See: https://musescore.org/en/node/292366
						///chords[c].notes[n].selected = true; // TODO: this doesn't exist; will currently only move the last note to the target layer. -RB 3/11/2020
				  }
			}      
			/////////////////////////////////////////////////////////////

			var cmdVoiceIndex = ctrlComboBoxVoice.currentIndex + 1;
			console.log("moveToVoice() is attempting to move selected notes (in selected levels) to layer " + cmdVoiceIndex);
			cmd("voice-" + cmdVoiceIndex);
			console.log("moveToVoice() cmd call was executed.");

			curScore.endCmd(); // Finish off the undo record.

			wereNotesMoved = true;
		}
		else {
			console.log("moveToVoice() did NOT move any notes to the target layer.");
		}

		console.log("Ending moveToVoice()");

		return wereNotesMoved;
	}

	function pruneStack() {
		console.log("Starting pruneStack()");

		// Get the selected chords in the selected segment...
		var chords = new Array();
		getAllChordsInRange(chords);

		var notesToDelete = new Array();

		var levels = new Array();
		if (ctrlCheckBoxLevel8.checked) {
			levels.push(8);
		}
		if (ctrlCheckBoxLevel7.checked) {
			levels.push(7);
		}
		if (ctrlCheckBoxLevel6.checked) {
			levels.push(6);
		}
		if (ctrlCheckBoxLevel5.checked) {
			levels.push(5);
		}
		if (ctrlCheckBoxLevel4.checked) {
			levels.push(4);
		}
		if (ctrlCheckBoxLevel3.checked) {
			levels.push(3);
		}
		if (ctrlCheckBoxLevel2.checked) {
			levels.push(2);
		}
		if (ctrlCheckBoxLevel1.checked) {
			levels.push(1);
		}

		console.log("# of chords: " + chords.length);
		console.log("# of levels to prune: " + levels.length);

		// NOTE: previous versions crashed when deleting all notes from a chord.
		// We will continue to detect this in 3.x even though it may no longer
		// be an issue in 3.x - no real purpose in deleting all notes.  -RB
		var emptyChordPotential = false;

		for (var c = 0; c < chords.length; c++) {
			var notesInChord = chords[c].notes.length;

			console.log("# of notes in chord # " + (c + 1) + ":" + notesInChord);

			var notesQueuedToDeleteInChord = 0;

			for (var n = 0; n < chords[c].notes.length; n++) {
				for (var j = 0; j < levels.length; j++) {
					if ((levels[j] - 1) != n) {
						//console.log("Skipped note #" + (n+1) + " at level #" + levels[j] + " in chord #" + (c+1));
						continue;
					}

					notesToDelete.push(chords[c].notes[n]);
					notesQueuedToDeleteInChord++;

					console.log("Added a note to delete at level #" + levels[j] + " in chord #" + (c + 1) + " - # notes in chord: " + notesInChord);

					if (notesQueuedToDeleteInChord >= notesInChord) {
						console.log("Empty chord potential detected at level #" + levels[j] + " in chord #" + (c + 1));
						emptyChordPotential = true;
					}
				}
			}
		}

		var pruned = false;
		var whyNoPrune = qsTr("");

		if (notesToDelete.length > 0) {
			curScore.startCmd();   // Start collecting undo info. -DLLarson (Dale)
			if (emptyChordPotential == false) {
				for (var n = 0; n < notesToDelete.length; n++) {
					var chord = notesToDelete[n].parent;
					chord.remove(notesToDelete[n]);
					pruned = true;
				}
			}
			else {
				console.log("No notes pruned as the requested prune levels would create an empty chord, which is not allowed!");
				whyNoPrune = qsTr("Can't do - would create an empty chord! Try reducing levels.");
				pruned = false;
			}
			curScore.endCmd(); // Finish off the undo record. -DLLarson (Dale)
		}

		// only if something pruned do we display a message...
		if (pruned == false) {
			var msg = whyNoPrune.length > 0 ? whyNoPrune : qsTr("Nothing pruned! Select the level(s) that match your chord stack sizes.");
			displayMessageDlg(msg);
		}

		console.log("Ending pruneStack()");

		return pruned;
	}

	onRun: {
		if (!curScore) {
			error("No score open.\nPruneStack requires an open score to run.\n");
			quit();
		}
	}

	Rectangle {
		id: ctrlRectangle
		property alias mouseArea: mouseArea
		property alias btnPruneStack: btnPruneStack
		property alias btnMoveToVoice: btnMoveToVoice
		property alias btnClose: btnClose
		property alias ctrlHintLabel: ctrlHintLabel
		property alias ctrlMessageDialog: ctrlMessageDialog

		width: 400
		height: 240
		color: "#9668a0"

		MessageDialog {
			id: ctrlMessageDialog
			title: "PruneStack Message"
			text: "Welcome to PruneStack!"
			visible: false
			onAccepted: {
				ctrlMessageDialog.close()
			}
		}

		MouseArea {
			id: mouseArea
			anchors.rightMargin: 0
			anchors.bottomMargin: 0
			anchors.leftMargin: 0
			anchors.topMargin: 0
			anchors.fill: parent

			Text {
				id: ctrlStackRangeLabel
				x: 25
				y: 15
				width: 100
				text: "Levels:"
			}

			Column {
				id: ctrlColumn01
				x: 80
				y: 15
				CheckBox {
					id: ctrlCheckBoxLevel4
					text: qsTr("4")
				}
				CheckBox {
					id: ctrlCheckBoxLevel3
					text: qsTr("3")
				}
				CheckBox {
					id: ctrlCheckBoxLevel2
					text: qsTr("2")
				}
				CheckBox {
					id: ctrlCheckBoxLevel1
					text: qsTr("1")
				}
			}

			Column {
				id: ctrlColumn02
				x: 125
				y: 15
				CheckBox {
					id: ctrlCheckBoxLevel8
					text: qsTr("8")
				}
				CheckBox {
					id: ctrlCheckBoxLevel7
					text: qsTr("7")
				}
				CheckBox {
					id: ctrlCheckBoxLevel6
					text: qsTr("6")
				}
				CheckBox {
					id: ctrlCheckBoxLevel5
					text: qsTr("5")
				}
			}

			Text {
				id: ctrlVoicesLabel
				visible: false
				x: 292
				y: 96
				width: 100
				text: "Voice:"
			}

			ComboBox {
				id: ctrlComboBoxVoice
				visible: false
				width: 55
				currentIndex: 1
				x: 340
				y: 90
				model: ListModel {
					id: cbVoiceItems
					ListElement { text: "1" }
					ListElement { text: "2" }
					ListElement { text: "3" }
					ListElement { text: "4" }
				}
			}

			Button {
				id: btnPruneStack
				x: 245
				y: 15
				width: 150
				height: 35
				text: qsTr("Prune Stack")
				onClicked: {
					if (pruneStack()) {
						quit();
					}
				}
			}

			Button {
				id: btnMoveToVoice
				visible: false
				x: 245
				y: 55
				width: 150
				height: 35
				text: qsTr("Prune && Move to Voice")
				onClicked: {
					if (moveToVoice()) {
						quit();
					}
				}
			}

			Button {
				id: btnClose
				x: 270
				y: 200
				width: 125
				height: 35
				text: qsTr("Close")
				onClicked: {
					console.log("PruneStack closed.");
					quit();
				}
			}

			Text {
				id: ctrlHintLabel
				x: 20
				y: 200
				width: 250
				text: qsTr("Hint: check the levels you want to prune from the chord stacks.")
				font.italic: true
				color: "white"
				wrapMode: Text.WordWrap
				font.pointSize: 10
			}

		}

	}
}
