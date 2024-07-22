RAT_Locals = {}
local L = RAT_Locals
local addon = ...

L.ADDON = "RAT: ";
L.DOT = ".";
L.ADDON_FULL = "Raid Attendance Tracker (RAT)";
L.ADDON_VERSION = "Version: " .. C_AddOns.GetAddOnMetadata(addon, "Version");
L.ADDON_AUTHOR = "Author: " .. C_AddOns.GetAddOnMetadata(addon, "Author");
L.HELP1 = "All commands must be sent through whispers and not battle.net whispers. The public note shows each players R:(Rank) AP:(Attendace Points) M:(Missed AP) (Percent of possible AP gained)% and S:(Strikes)/3";
L.HELP2 = "There are 2 commands you can send to a RAT Officer: !rat bench - Puts you on the bench so you can leave the raid. !rat alt Main(Player) - Binds your current character to your main";

L.SYSTEM_STILL_SYNCING1 = "RAT IS STILL SYNCING, ";
L.SYSTEM_STILL_SYNCING2 = "IT DID NOT AWARD PLAYERS. ";
L.SYSTEM_STILL_SYNCING3 = "s LEFT.";
L.SYSTEM_UPDATE_COMPLETED = "Updated all players.";
L.SYSTEM_ALT_ADDED = " is now an alt of ";
L.SYSTEM_STARTED_SYNC = "Started data sync.";
L.SYSTEM_DELETED_DATA = " has purged all attendance related data.";
L.SYSTEM_DEBUG_ENABLED = "Debug mode has been enabled.";
L.SYSTEM_DEBUG_DISABLED = "Debug mode has been disabled.";

L.ERROR_BENCHED_ALREADY =" is already on the bench.";
L.ERROR_PLAYER_INELIGIBLE = " is not of an allowed rank nor an alt.";
L.ERROR_PLAYER_INELIGIBLE_OR = " or ";
L.ERROR_UNDO = "There is nothing to undo."
L.ERROR_ALT_ALREADY = " is already an alt of ";
L.ERROR_NOT_OFFICER = " Only players with permission to change officer note are allowed to execute this command.";
L.ERROR_OFFICER_NOTE_TOO_LONG1 = "CRITICAL ERROR! ";
L.ERROR_OFFICER_NOTE_TOO_LONG2 = "'s PUBLIC NOTE IS TOO LONG, MAX LENGTH IS 31 CHARACTERS!";
L.ERROR_NOTE_SYNTAX = "'s note has an incorrect syntax, reformating...";
L.ERROR_CHEAT_DETECTED1 = "CHEAT DETECTED in ";
L.ERROR_CHEAT_DETECTED2 = "'s note. Correct values are: ";
L.ERROR_CHEAT_DETECTED3 = " Values found are: ";
L.ERROR_NOT_GUILD_GROUP = "Did not award raid as it is not a guild group. Use: /rat award 1 to award anyway.";

L.SYNTAX_AWARD = "Incorrect syntax. Usage: /rat award Player Points(number) or /rat award Points(number).";
L.SYNTAX_ABSENT = "Incorrect syntax. Usage: /rat absent Player Points(number).";
L.SYNTAX_STRIKE = "Incorrect syntax. Usage: /rat strike Player Points(number).";
L.SYNTAX_IMPORT = "Incorrect syntax. Usage: /rat import Player Attended(number) Absent(number).";
L.SYNTAX_SWAP = "Incorrect syntax. Usage: /rat swap Player.";
L.SYNTAX_BENCH = "Incorrect syntax. Usage: /rat bench Player.";
L.SYNTAX_ALT = "Incorrect syntax. Usage: /rat alt Main Alt.";

L.BROADCAST_AWARDED_PLAYER1 = " recieved ";
L.BROADCAST_AWARDED_PLAYER2 = " attendance point(s).";
L.BROADCAST_AWARDED_ALL1 = "Awarded the following players with ";
L.BROADCAST_AWARDED_ALL2 = " attendance point(s): ";
L.BROADCAST_ABSENT_PLAYER1 = " recieved ";
L.BROADCAST_ABSENT_PLAYER2 = " absent point(s).";
L.BROADCAST_ABSENT_ALL = "The following players were absent: ";
L.BROADCAST_STRIKE_PLAYER1 = " recieved ";
L.BROADCAST_STRIKE_PLAYER2 = " strike(s).";
L.BROADCAST_IMPORT_PLAYER1 = "Imported new player ";
L.BROADCAST_IMPORT_PLAYER2 = " with ";
L.BROADCAST_IMPORT_PLAYER3 = " attendance point(s) and ";
L.BROADCAST_IMPORT_PLAYER4 = " absent point(s).";
L.BROADCAST_DELETED_PLAYER = "Deleted player ";
L.BROADCAST_SWAPED_PLAYER = " had 1 attendance point removed and 1 absent point added.";
L.BROADCAST_BENCHED_PLAYER = " has been added to the bench.";
L.BROADCAST_UNDONE_AWARD = "Last award has been undone.";
L.BROADCAST_AWARD_NEXT = "The next award will be given out in:";
L.BROADCAST_CALENDAR_PUNISHED = "The following players failed to respond to calendar invites and had their attendace point reverted: ";
L.BROADCAST_CC_ABSENT_PLAYER1 = "The following players recieved ";
L.BROADCAST_CC_ABSENT_PLAYER2 = " absent point(s): ";
L.BROADCAST_DST_CHANGE = "The next award was adjusted to match the daylight savings time change.";

L.SUMMARY1 = "RAT Summary: You have gained ";
L.SUMMARY2 = " AP and missed ";
L.SUMMARY3 = " points. You have ";
L.SUMMARY4 = " rank(s).";

L.OPTIONS_LEFT_BUTTON = "<----  Back";
L.OPTIONS_PAGE_TEXT1 = "Step ";
L.OPTIONS_PAGE_TEXT2 = " /6";
L.OPTIONS_RIGHT_BUTTON = "Next  ---->";
L.OPTIONS_SCAN_RT_BUTTON = "Scan for raid times\n(recommended)";
L.OPTIONS_DAY_TEXT = "Day";
L.OPTIONS_START_TEXT = "Start";
L.OPTIONS_FINISH_TEXT = "Finish";
L.OPTIONS_SERVER_TIMEZONE_TEXT = "Server Timezone";
L.OPTIONS_RANK_TEXT = "Rank";
L.OPTIONS_SCAN_RR_BUTTON = "Scan for ranks\n(recommended)";
L.OPTIONS_SORT_RANK_TEXT = "Algorithm to sort ranks";
L.OPTIONS_FREQUENCY_TEXT = "Give points every (in minutes)";
L.OPTIONS_AWARD_START_TEXT = "Award at raid start";
L.OPTIONS_PUNISH_CALENDAR_TEXT = "Punish unaswered calendar invites";
L.OPTIONS_SETUP_TITLE = "SETUP";
L.OPTIONS_RAID_TIMES_TITLE = "RAID TIMES";
L.OPTIONS_RAIDER_RANKS_TITLE = "RAIDER RANKS";
L.OPTIONS_SETTINGS_TITLE = "SETTINGS";
L.OPTIONS_SETUP_COMPLETED_TITLE = "SETUP COMPLETED";
L.OPTIONS_HELP_TITLE = "HELP/COMMANDS";
L.OPTIONS_COMMAND_CENTER_TITLE = "COMMAND CENTER";
L.OPTIONS_UNDO_BUTTON = "Undo last award\n(done by you)";
L.OPTIONS_RIGHT_BUTTON_DONE = "Done";
L.OPTIONS_SKIP_BUTTON = "Skip the current\nor coming raid";
L.OPTIONS_SETUP_BUTTON = "Start setup";
L.OPTIONS_DELETE_BUTTON = "Delete ALL data";
L.OPTIONS_AWARD_ALL_BUTTON = "Award all players in\nraid, others absent";
L.OPTIONS_ACTION_BUTTON = "OK.";
L.OPTIONS_ACTION_TEXT = "Action:";
L.OPTIONS_AMOUNT_TEXT = "Amount:";
L.OPTIONS_MARK_BUTTON = "Mark All";
L.OPTIONS_UNMARK_BUTTON = "Unmark All";
L.OPTIONS_MINIMAP_CLICK = "Click to open the settings";
L.OPTIONS_MINIMAP_MODE_TEXT = "Show minimap button:";

L.SETUP_INFO_TEXT = "Thank you, for downloading and installing Raid Attendance Tracker.\n\nThis is a quick setup that will help you customize and configure the addon to work specifically for your guild.\n\nIt only takes a minute but in case you dont have the time right now you can always do it later.\n\nYou can find the quick setup in the addons interface options.";
L.SETUP_RT_INFO_TEXT = "Fill in your raid times in the boxes below, using the format HH:MM i.e 20:30. It is recommended that you first scan for raid times to possibly save time then complement missing data.";
L.SETUP_RR_INFO_TEXT = "Check the boxes with the ranks containing raiders main. Do not include any ranks with only alts, since alts can be linked to the mains. It is recommended to first scan for ranks to possibly save time then complement missing data.";
L.SETUP_SETTINGS_INFO_TEXT = "Configure the addon to match your guilds needs. Hover the info buttons for help with each setting.";
L.SETUP_COMPLETED_INFO_TEXT1 = "Setup has now been completed. You can adjust and change any of these settings by going to the interface options, pressing the minimap button or typing /rat.\n\nHere is a list of commands that players can send to Officers with RAT\n(ONLY IN WHISPERS NOT THROUGH BATTLE.NET):\n|cFFFF0000!rat help |r|cFFFFFFFF- informs the player of the commands they can use as well as what the public note means.|r\n|cFFFF0000!rat bench |r|cFFFFFFFF- Puts the player on the bench|r\n|cFFFF0000!rat alt Main |r|cFFFFFFFF- binds the active user to specified main.\n\nIn the public note each players stats will be listed in the following way:|r\n|cFFFF0000R:1 |r|cFFFFFFFF- Means player is Rank 1|r\n|cFFFF0000AP:95 |r|cFFFFFFFF- How many attendance points a player has.|r\n|cFFFF0000M:5 |r|cFFFFFFFF- How many points a player has missed.|r\n|cFFFF000095% |r|cFFFFFFFF- How many % of possible attendance points the player has.|r\n|cFFFF0000S:0/3 |r|cFFFFFFFF- How many strikes a player has, managed at your discretion.|r";
L.SETUP_COMPLETED_INFO_TEXT2 = "Here is a list of useful slash commands\n(all commands starts with |cFFFF0000/rat|r|cFFFFFFFF):|r\n|cFFFF0000alt Main Alt|r|cFFFFFFFF - binds Alt to Main|r\n|cFFFF0000bench Player|r|cFFFFFFFF - puts the Player on the bench|r\n|cFFFF0000skip|r|cFFFFFFFF - skips to the next raid (be careful, can't be undone)|r\n|cFFFF0000undo |r|cFFFFFFFF- reverts the latest award made by you manually or automatically|r\n|cFFFF0000ranks |r|cFFFFFFFF- opens a window to look at all mains and their rank|r\n|cFFFF0000award Amount(number) |r|cFFFFFFFF- awards everyone in the raid the specified amount|r\n|cFFFF0000award Player Amount(number) |r|cFFFFFFFF- awards the specified player the specified amount|r\n|cFFFF0000absent Player Amount(number) |r|cFFFFFFFF- gives the specified player the specified amount of absent points|r\n|cFFFF0000bench Player |r|cFFFFFFFF- puts the specified player on the bench.|r\n|cFFFF0000strike Player Amount(number)|r|cFFFFFFFF - gives the specified player the specified amount of strikes.|r\n\n|cFFFF0000Only officer should be able to edit officer notes as the officer and public note is the database for RAT.|r";
L.SETUP_SORT_RANKS_TOOLTIP = "Players will be ranked with consideration to their percent and attendance points to easier determine who has the best attendance.\n\nRAT-Algorithm(highly recommended): Uses a complex Algorithm written by Naturage-Kazzak and is used by <Endless>-Kazzak.\n\nThe more attendance points you have the less weight they have while percent weights higher, while someone with very few attendance points \nwill have their percent at a low weight.\n\nThis makes it very competitive and very possible to catch up to the rank 1 spot for anyone as time passes unless the rank 1 person never misses a raid of course.\n\nHighest percent sorts by percent which is very benefitial for new player as they are likely to have 100%.\n\nMost points sorts by attendance points which benefits the one who has been in the guild the most and it is hard to catch up.";
L.SETUP_FREQUENCY_TOOLTIP = "This determines how often attendance points will be given out.\n\nDefault is every 60 minutes.";
L.SETUP_AWARD_RAID_START_TOOLTIP = "This determines if attendance points should be given out when the raid starts, else it will be raid start + frequency\n\nDefault is on.";
L.SETUP_PUNISH_CALENDAR_TOOLTIP = "This determines if players who did not answer or put tentative should have the first attendance point removed and be a miss instead.\n\nThis is to incentivice players to accept the calendar on time.\n\nDefault is off.";

