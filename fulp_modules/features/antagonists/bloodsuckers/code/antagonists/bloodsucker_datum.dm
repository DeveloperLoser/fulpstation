/datum/antagonist/bloodsucker
	name = "\improper Bloodsucker"
	show_in_antagpanel = TRUE
	roundend_category = "bloodsuckers"
	antagpanel_category = "Bloodsucker"
	job_rank = ROLE_BLOODSUCKER
	antag_hud_name = "bloodsucker"
	show_name_in_check_antagonists = TRUE
	can_coexist_with_others = FALSE
	hijack_speed = 0.5
	hud_icon = 'fulp_modules/features/antagonists/bloodsuckers/icons/bloodsucker_icons.dmi'
	ui_name = "AntagInfoBloodsucker"
	tips = BLOODSUCKER_TIPS
	preview_outfit = /datum/outfit/bloodsucker_outfit

	/// How much blood we have, starting off at default blood levels.
	var/bloodsucker_blood_volume = BLOOD_VOLUME_NORMAL
	/// How much blood we can have at once, increases per level.
	var/max_blood_volume = 600

	// TIMERS //
	///Timer between alerts for Burn messages
	COOLDOWN_DECLARE(static/bloodsucker_spam_sol_burn)
	///Timer between alerts for Healing messages
	COOLDOWN_DECLARE(static/bloodsucker_spam_healing)

	///Used for assigning your name
	var/bloodsucker_name
	///Used for assigning your title
	var/bloodsucker_title
	///Used for assigning your reputation
	var/bloodsucker_reputation

	///Amount of Humanity lost
	var/humanity_lost = 0
	///Have we been broken the Masquerade?
	var/broke_masquerade = FALSE
	///How many Masquerade Infractions do we have?
	var/masquerade_infractions = 0
	///Blood required to enter Frenzy
	var/frenzy_threshold = FRENZY_THRESHOLD_ENTER
	///If we are currently in a Frenzy
	var/frenzied = FALSE

	///ALL Powers currently owned
	var/list/datum/action/powers = list()
	///Bloodsucker Clan - Used for dealing with Sol
	var/datum/team/vampireclan/clan
	///Frenzy Grab Martial art given to Bloodsuckers in a Frenzy
	var/datum/martial_art/frenzygrab/frenzygrab = new
	///You get assigned a Clan once you Rank up enough
	var/my_clan = NONE

	///Vassals under my control. Periodically remove the dead ones.
	var/list/datum/antagonist/vassal/vassals = list()
	///Have we selected our Favorite Vassal yet?
	var/has_favorite_vassal = FALSE

	var/bloodsucker_level
	var/bloodsucker_level_unspent = 1
	var/passive_blood_drain = -0.1
	var/additional_regen
	var/bloodsucker_regen_rate = 0.3

	// Used for Bloodsucker Objectives
	var/area/lair
	var/obj/structure/closet/crate/coffin
	var/total_blood_drank = 0
	var/frenzy_blood_drank = 0
	var/frenzies = 0
	/// If we're currently getting dusted, we won't final death repeatedly.
	var/dust_timer

	///Blood display HUD
	var/atom/movable/screen/bloodsucker/blood_counter/blood_display
	///Vampire level display HUD
	var/atom/movable/screen/bloodsucker/rank_counter/vamprank_display
	///Sunlight timer HUD
	var/atom/movable/screen/bloodsucker/sunlight_counter/sunlight_display

	/// Static typecache of all bloodsucker powers.
	var/static/list/all_bloodsucker_powers = typecacheof(/datum/action/cooldown/bloodsucker, ignore_root_path = TRUE)
	/// Antagonists that cannot be Vassalized no matter what
	var/list/vassal_banned_antags = list(
		/datum/antagonist/bloodsucker,
		/datum/antagonist/monsterhunter,
		/datum/antagonist/changeling,
		/datum/antagonist/cult,
		/datum/antagonist/heretic,
		/datum/antagonist/xeno,
		/datum/antagonist/obsessed,
		/datum/antagonist/ert/safety_moth,
	)
	///Default Bloodsucker traits
	var/static/list/bloodsucker_traits = list(
		TRAIT_NOBREATH,
		TRAIT_SLEEPIMMUNE,
		TRAIT_NOCRITDAMAGE,
		TRAIT_RESISTCOLD,
		TRAIT_RADIMMUNE,
		TRAIT_GENELESS,
		TRAIT_STABLEHEART,
		TRAIT_NOSOFTCRIT,
		TRAIT_NOHARDCRIT,
		TRAIT_AGEUSIA,
		TRAIT_NOPULSE,
		TRAIT_COLDBLOODED,
		TRAIT_VIRUSIMMUNE,
		TRAIT_TOXIMMUNE,
		TRAIT_HARDLY_WOUNDED,
	)

/mob/living/proc/explain_powers()
	set name = "Bloodsucker Help"
	set category = "Mentor"

	var/datum/antagonist/bloodsucker/bloodsuckerdatum = mind.has_antag_datum(/datum/antagonist/bloodsucker)
	var/choice = tgui_input_list(usr, "What Power are you looking into?", "Mentorhelp v2", bloodsuckerdatum.powers)
	if(!choice)
		return
	var/datum/action/cooldown/bloodsucker/power = choice
	to_chat(usr, span_warning("[power.power_explanation]"))

/// These handles the application of antag huds/special abilities
/datum/antagonist/bloodsucker/apply_innate_effects(mob/living/mob_override)
	. = ..()
	var/mob/living/current_mob = mob_override || owner.current
	RegisterSignal(current_mob, COMSIG_LIVING_LIFE, .proc/LifeTick)
	handle_clown_mutation(current_mob, mob_override ? null : "As a vampiric clown, you are no longer a danger to yourself. Your clownish nature has been subdued by your thirst for blood.")
	add_team_hud(current_mob)
	if(current_mob.hud_used)
		var/datum/hud/hud_used = current_mob.hud_used
		//blood
		blood_display = new /atom/movable/screen/bloodsucker/blood_counter()
		blood_display.hud = hud_used
		hud_used.infodisplay += blood_display
		//rank
		vamprank_display = new /atom/movable/screen/bloodsucker/rank_counter()
		vamprank_display.hud = hud_used
		hud_used.infodisplay += vamprank_display
		//sun
		sunlight_display = new /atom/movable/screen/bloodsucker/sunlight_counter()
		sunlight_display.hud = hud_used
		hud_used.infodisplay += sunlight_display
		//update huds
		hud_used.show_hud(hud_used.hud_version)
	else
		RegisterSignal(current_mob, COMSIG_MOB_HUD_CREATED, .proc/on_hud_created)

/datum/antagonist/bloodsucker/remove_innate_effects(mob/living/mob_override)
	. = ..()
	var/mob/living/current_mob = mob_override || owner.current
	UnregisterSignal(current_mob, COMSIG_LIVING_LIFE)
	handle_clown_mutation(current_mob, removing = FALSE)
	if(current_mob.hud_used)
		var/datum/hud/hud_used = current_mob.hud_used

		hud_used.infodisplay -= blood_display
		hud_used.infodisplay -= vamprank_display
		hud_used.infodisplay -= sunlight_display
		QDEL_NULL(blood_display)
		QDEL_NULL(vamprank_display)
		QDEL_NULL(sunlight_display)

/datum/antagonist/bloodsucker/proc/on_hud_created(datum/source)
	SIGNAL_HANDLER

	var/datum/hud/bloodsucker_hud = owner.current.hud_used

	blood_display = new /atom/movable/screen/bloodsucker/blood_counter()
	blood_display.hud = bloodsucker_hud
	bloodsucker_hud.infodisplay += blood_display

	vamprank_display = new /atom/movable/screen/bloodsucker/rank_counter()
	vamprank_display.hud = bloodsucker_hud
	bloodsucker_hud.infodisplay += vamprank_display

	sunlight_display = new /atom/movable/screen/bloodsucker/sunlight_counter()
	sunlight_display.hud = bloodsucker_hud
	bloodsucker_hud.infodisplay += sunlight_display

	bloodsucker_hud.show_hud(bloodsucker_hud.hud_version)

/datum/antagonist/bloodsucker/get_admin_commands()
	. = ..()
	.["Give Level"] = CALLBACK(src, .proc/RankUp)
	if(bloodsucker_level_unspent >= 1)
		.["Remove Level"] = CALLBACK(src, .proc/RankDown)

	if(broke_masquerade)
		.["Fix Masquerade"] = CALLBACK(src, .proc/fix_masquerade)
	else
		.["Break Masquerade"] = CALLBACK(src, .proc/break_masquerade)

/// Called by the add_antag_datum() mind proc after the instanced datum is added to the mind's antag_datums list.
/datum/antagonist/bloodsucker/on_gain()
	if(IS_VASSAL(owner.current)) // Vassals shouldnt be getting the same benefits as Bloodsuckers.
		bloodsucker_level_unspent = 0
	else
		// Start Sunlight if first Bloodsucker
		clan.check_start_sunlight()
		// Name and Titles
		SelectFirstName()
		SelectTitle(am_fledgling = TRUE)
		SelectReputation(am_fledgling = TRUE)
		// Objectives
		forge_bloodsucker_objectives()

	. = ..()
	// Assign Powers
	AssignStarterPowersAndStats()

/// Called by the remove_antag_datum() and remove_all_antag_datums() mind procs for the antag datum to handle its own removal and deletion.
/datum/antagonist/bloodsucker/on_removal()
	/// End Sunlight? (if last Vamp)
	clan.check_cancel_sunlight()
	ClearAllPowersAndStats()
	return ..()

/datum/antagonist/bloodsucker/on_body_transfer(mob/living/old_body, mob/living/new_body)
	. = ..()
	for(var/datum/action/cooldown/bloodsucker/all_powers as anything in powers)
		all_powers.Remove(old_body)
		all_powers.Grant(new_body)
	var/old_punchdamagelow
	var/old_punchdamagehigh
	if(ishuman(old_body))
		var/mob/living/carbon/human/old_user = old_body
		var/datum/species/old_species = old_user.dna.species
		old_species.species_traits -= DRINKSBLOOD
		//Keep track of what they were
		old_punchdamagelow = old_species.punchdamagelow
		old_punchdamagehigh = old_species.punchdamagehigh
		//Then reset them
		old_species.punchdamagelow = initial(old_species.punchdamagelow)
		old_species.punchdamagehigh = initial(old_species.punchdamagehigh)
	if(ishuman(new_body))
		var/mob/living/carbon/human/new_user = new_body
		var/datum/species/new_species = new_user.dna.species
		new_species.species_traits += DRINKSBLOOD
		//Give old punch damage values
		new_species.punchdamagelow = old_punchdamagelow
		new_species.punchdamagehigh = old_punchdamagehigh

	//Give Bloodsucker Traits
	for(var/all_traits in bloodsucker_traits)
		REMOVE_TRAIT(old_body, all_traits, BLOODSUCKER_TRAIT)
		ADD_TRAIT(new_body, all_traits, BLOODSUCKER_TRAIT)

/datum/antagonist/bloodsucker/greet()
	. = ..()
	var/fullname = ReturnFullName(TRUE)
	to_chat(owner, span_userdanger("You are [fullname], a strain of vampire known as a Bloodsucker!"))
	owner.announce_objectives()
	if(bloodsucker_level_unspent >= 2)
		to_chat(owner, span_announce("As a latejoiner, you have [bloodsucker_level_unspent] bonus Ranks, entering your claimed coffin allows you to spend a Rank."))
	owner.current.playsound_local(null, 'fulp_modules/features/antagonists/bloodsuckers/sounds/BloodsuckerAlert.ogg', 100, FALSE, pressure_affected = FALSE)
	antag_memory += "Although you were born a mortal, in undeath you earned the name <b>[fullname]</b>.<br>"

/datum/antagonist/bloodsucker/farewell()
	to_chat(owner.current, span_userdanger("<FONT size = 3>With a snap, your curse has ended. You are no longer a Bloodsucker. You live once more!</FONT>"))
	// Refill with Blood so they don't instantly die.
	owner.current.blood_volume = max(owner.current.blood_volume, BLOOD_VOLUME_NORMAL)

/datum/antagonist/bloodsucker/proc/add_objective(datum/objective/added_objective)
	objectives += added_objective

/datum/antagonist/bloodsucker/proc/remove_objectives(datum/objective/removed_objective)
	objectives -= removed_objective

// Called when using admin tools to give antag status
/datum/antagonist/bloodsucker/admin_add(datum/mind/new_owner, mob/admin)
	var/levels = input("How many unspent Ranks would you like [new_owner] to have?","Bloodsucker Rank", bloodsucker_level_unspent) as null | num
	var/msg = " made [key_name_admin(new_owner)] into \a [name]"
	if(levels > 1)
		bloodsucker_level_unspent = levels
		msg += " with [levels] extra unspent Ranks."
	message_admins("[key_name_admin(usr)][msg]")
	log_admin("[key_name(usr)][msg]")
	new_owner.add_antag_datum(src)

/datum/antagonist/bloodsucker/get_preview_icon()

	var/icon/final_icon = render_preview_outfit(/datum/outfit/bloodsucker_outfit)
	final_icon.Blend(icon('icons/effects/blood.dmi', "uniformblood"), ICON_OVERLAY)

	return finish_preview_icon(final_icon)

/**
 *	# Vampire Clan
 *
 *	This is used for dealing with the Vampire Clan.
 *	This handles Sol for Bloodsuckers, making sure to not have several.
 *	None of this should appear in game, we are using it JUST for Sol. All Bloodsuckers should have their individual report.
 */

/datum/team/vampireclan
	name = "Clan"

	/// Sunlight Timer. Created on first Bloodsucker assign. Destroyed on last removed Bloodsucker.
	var/obj/effect/sunlight/bloodsucker_sunlight

/datum/antagonist/bloodsucker/create_team(datum/team/vampireclan/team)
	if(!team)
		for(var/datum/antagonist/bloodsucker/bloodsuckerdatums in GLOB.antagonists)
			if(!bloodsuckerdatums.owner)
				continue
			if(bloodsuckerdatums.clan)
				clan = bloodsuckerdatums.clan
				return
		clan = new /datum/team/vampireclan
		return
	if(!istype(team))
		stack_trace("Wrong team type passed to [type] initialization.")
	clan = team

/datum/antagonist/bloodsucker/get_team()
	return clan

/datum/team/vampireclan/roundend_report()
	if(members.len <= 0)
		return
	var/list/report = list()
	report += "<span class='header'>Lurking in the darkness, the Bloodsuckers were:</span><br>"
	for(var/datum/mind/mind_members in members)
		for(var/datum/antagonist/bloodsucker/individual_bloodsuckers in mind_members.antag_datums)
			if(mind_members.has_antag_datum(/datum/antagonist/vassal)) // Skip over Ventrue's Favorite Vassal
				continue
			report += individual_bloodsuckers.roundend_report()

	return "<div class='panel redborder'>[report.Join("<br>")]</div>"

/// Individual roundend report
/datum/antagonist/bloodsucker/roundend_report()
	// Get the default Objectives
	var/list/report = list()
	// Vamp name
	report += "<br><span class='header'><b>\[[ReturnFullName(TRUE)]\]</b></span>"
	report += printplayer(owner)
	// Clan (Actual Clan, not Team) name
	if(my_clan != NONE)
		report += "They were part of the <b>[my_clan]</b>!"

	// Default Report
	var/objectives_complete = TRUE
	if(objectives.len)
		report += printobjectives(objectives)
		for(var/datum/objective/objective in objectives)
			if(objective.objective_name == "Optional Objective")
				continue
			if(!objective.check_completion())
				objectives_complete = FALSE
				break

	// Now list their vassals
	if(vassals.len > 0)
		report += "<span class='header'>Their Vassals were...</span>"
		for(var/datum/antagonist/vassal/all_vassals in vassals)
			if(all_vassals.owner)
				var/jobname = all_vassals.owner.assigned_role ? "the [all_vassals.owner.assigned_role.title]" : ""
				report += "<b>[all_vassals.owner.name]</b> [jobname][all_vassals.favorite_vassal == TRUE ? " and was the <b>Favorite Vassal</b>" : ""]"

	if(objectives.len == 0 || objectives_complete)
		report += "<span class='greentext big'>The [name] was successful!</span>"
	else
		report += "<span class='redtext big'>The [name] has failed!</span>"

	return report

/**
 *	# Assigning Sol
 *
 *	Sol is the sunlight, during this period, all Bloodsuckers must be in their coffin, else they burn.
 *	This was originally dealt with by the gamemode, but as gamemodes no longer exist, it is dealt with by the team.
 */

/// Start Sol, called when someone is assigned Bloodsucker
/datum/team/vampireclan/proc/check_start_sunlight()
	if(members.len <= 1)
		message_admins("New Sol has been created due to Bloodsucker assignment.")
		bloodsucker_sunlight = new()

/// End Sol, if you're the last Bloodsucker
/datum/team/vampireclan/proc/check_cancel_sunlight()
	// No minds in the clan? Delete Sol.
	if(members.len <= 1)
		message_admins("Sol has been deleted due to the lack of Bloodsuckers")
		QDEL_NULL(bloodsucker_sunlight)

/// Buying powers
/datum/antagonist/bloodsucker/proc/BuyPower(datum/action/cooldown/bloodsucker/power)
	powers += power
	power.Grant(owner.current)
	log_uplink("[key_name(owner.current)] purchased [power].")

/datum/antagonist/bloodsucker/proc/RemovePower(datum/action/cooldown/bloodsucker/power)
	if(power.active)
		power.DeactivatePower()
	powers -= power
	power.Remove(owner.current)

/datum/antagonist/bloodsucker/proc/AssignStarterPowersAndStats()
	// Purchase Roundstart Powers
	BuyPower(new /datum/action/cooldown/bloodsucker/feed)
	BuyPower(new /datum/action/cooldown/bloodsucker/masquerade)
	if(!IS_VASSAL(owner.current)) // Favorite Vassal gets their own.
		BuyPower(new /datum/action/cooldown/bloodsucker/veil)
	add_verb(owner.current, /mob/living/proc/explain_powers)
	//Traits: Species
	var/mob/living/carbon/human/user = owner.current
	if(ishuman(owner.current))
		var/datum/species/user_species = user.dna.species
		user_species.species_traits += DRINKSBLOOD
		user.dna?.remove_all_mutations()
		user_species.punchdamagelow += 1 //lowest possible punch damage - 0
		user_species.punchdamagehigh += 1 //highest possible punch damage - 9
	//Give Bloodsucker Traits
	for(var/all_traits in bloodsucker_traits)
		ADD_TRAIT(owner.current, all_traits, BLOODSUCKER_TRAIT)
	//Clear Addictions
	for(var/addiction_type in subtypesof(/datum/addiction))
		owner.current.mind.remove_addiction_points(addiction_type, MAX_ADDICTION_POINTS)
	//No Skittish "People" allowed
	if(HAS_TRAIT(owner.current, TRAIT_SKITTISH))
		REMOVE_TRAIT(owner.current, TRAIT_SKITTISH, ROUNDSTART_TRAIT)
	// Tongue & Language
	owner.current.grant_all_languages(FALSE, FALSE, TRUE)
	owner.current.grant_language(/datum/language/vampiric)
	/// Clear Disabilities & Organs
	HealVampireOrgans()

/datum/antagonist/bloodsucker/proc/ClearAllPowersAndStats()
	// Powers
	remove_verb(owner.current, /mob/living/proc/explain_powers)
	for(var/datum/action/cooldown/bloodsucker/all_powers as anything in powers)
		RemovePower(all_powers)
	/// Stats
	if(ishuman(owner.current))
		var/mob/living/carbon/human/user = owner.current
		var/datum/species/user_species = user.dna.species
		user_species.species_traits -= DRINKSBLOOD
		// Clown
		if(istype(user) && owner.assigned_role == "Clown")
			user.dna.add_mutation(/datum/mutation/human/clumsy)
	/// Remove ALL Traits, as long as its from BLOODSUCKER_TRAIT's source. - This is because of unique cases like Nosferatu getting Ventcrawling.
	for(var/all_status_traits in owner.current.status_traits)
		REMOVE_TRAIT(owner.current, all_status_traits, BLOODSUCKER_TRAIT)
	/// Update Health
	owner.current.setMaxHealth(MAX_LIVING_HEALTH)
	// Language
	owner.current.remove_language(/datum/language/vampiric)
	/// Heart
	RemoveVampOrgans()
	/// Eyes
	var/mob/living/carbon/user = owner.current
	var/obj/item/organ/internal/eyes/user_eyes = user.getorganslot(ORGAN_SLOT_EYES)
	if(user_eyes)
		user_eyes.flash_protect += 1
		user_eyes.sight_flags = 0
		user_eyes.see_in_dark = 2
		user_eyes.lighting_alpha = LIGHTING_PLANE_ALPHA_VISIBLE
	user.update_sight()

/datum/antagonist/bloodsucker/proc/give_masquerade_infraction()
	if(broke_masquerade)
		return
	masquerade_infractions++
	if(masquerade_infractions >= 3)
		break_masquerade()
	else
		to_chat(owner.current, span_cultbold("You violated the Masquerade! Break the Masquerade [3 - masquerade_infractions] more times and you will become a criminal to the Bloodsucker's Cause!"))

/datum/antagonist/bloodsucker/proc/RankUp()
	set waitfor = FALSE
	var/datum/antagonist/vassal/vassaldatum = IS_VASSAL(owner.current)
	if(!owner || !owner.current || vassaldatum)
		return
	bloodsucker_level_unspent++
	// Spend Rank Immediately?
	if(istype(owner.current.loc, /obj/structure/closet/crate/coffin))
		if(my_clan == CLAN_VENTRUE)
			to_chat(owner, span_announce("You have recieved a new Rank to level up your Favorite Vassal with!"))
			return
		SpendRank()
	else
		to_chat(owner, span_notice("<EM>You have grown more ancient! Sleep in a coffin that you have claimed to thicken your blood and become more powerful.</EM>"))
		if(bloodsucker_level_unspent >= 2)
			to_chat(owner, span_announce("Bloodsucker Tip: If you cannot find or steal a coffin to use, you can build one from wood or metal."))

/datum/antagonist/bloodsucker/proc/RankDown()
	bloodsucker_level_unspent--

/datum/antagonist/bloodsucker/proc/remove_nondefault_powers()
	for(var/datum/action/cooldown/bloodsucker/power as anything in powers)
		if(istype(power, /datum/action/cooldown/bloodsucker/feed) || istype(power, /datum/action/cooldown/bloodsucker/masquerade) || istype(power, /datum/action/cooldown/bloodsucker/veil))
			continue
		RemovePower(power)

/datum/antagonist/bloodsucker/proc/LevelUpPowers()
	for(var/datum/action/cooldown/bloodsucker/power as anything in powers)
		if(istype(power, /datum/action/cooldown/bloodsucker/targeted/tremere))
			continue
		power.level_current++

///Disables all powers, accounting for torpor
/datum/antagonist/bloodsucker/proc/DisableAllPowers()
	for(var/datum/action/cooldown/bloodsucker/power as anything in powers)
		if((power.check_flags & BP_CANT_USE_IN_TORPOR) && HAS_TRAIT(owner.current, TRAIT_NODEATH))
			if(power.active)
				power.DeactivatePower()

#define PURCHASE_VASSAL "Vassal"
#define PURCHASE_TREMERE "Tremere"
#define PURCHASE_DEFAULT "Default"

/datum/antagonist/bloodsucker/proc/SpendRank(mob/living/carbon/human/target, spend_rank = TRUE, spend_blood = FALSE)
	set waitfor = FALSE

	var/datum/antagonist/vassal/vassaldatum = target?.mind.has_antag_datum(/datum/antagonist/vassal)
	if(!owner || !owner.current || !owner.current.client || (spend_rank && bloodsucker_level_unspent <= 0))
		return
	//Who am I purchasing Powers for?
	var/power_mode = PURCHASE_DEFAULT
	var/upgrade_message = "You have the opportunity to grow more ancient. Select a power to advance your Rank."
	if(target)
		power_mode = PURCHASE_VASSAL
		upgrade_message = "You have the opportunity to level up your Favorite Vassal. Select a power you wish them to recieve."
	if(my_clan == CLAN_TREMERE)
		power_mode = PURCHASE_TREMERE
		upgrade_message = "You have the opportunity to grow more ancient. Select a power you wish to upgrade."
	// Purchase Power Prompt
	var/list/options = list()
	switch(power_mode)
		if(PURCHASE_DEFAULT)
			for(var/datum/action/cooldown/bloodsucker/power as anything in all_bloodsucker_powers)
				if(initial(power.purchase_flags) & BLOODSUCKER_CAN_BUY && !(locate(power) in powers))
					options[initial(power.name)] = power
		if(PURCHASE_VASSAL)
			for(var/datum/action/cooldown/bloodsucker/power as anything in all_bloodsucker_powers)
				if(initial(power.purchase_flags) & VASSAL_CAN_BUY && !(locate(power) in vassaldatum.powers))
					options[initial(power.name)] = power
		if(PURCHASE_TREMERE)
			for(var/datum/action/cooldown/bloodsucker/targeted/tremere/power as anything in powers)
				if(!(power.purchase_flags & TREMERE_CAN_BUY))
					continue
				if(isnull(power.upgraded_power))
					continue
				options[initial(power.name)] = power

	if(options.len < 1)
		to_chat(owner.current, span_notice("You grow more ancient by the night!"))
	else
		// Give them the UI to purchase a power.
		var/choice = tgui_input_list(owner.current, upgrade_message, "Your Blood Thickens...", options)
		// Prevent Bloodsuckers from closing/reopning their coffin to spam Levels.
		if(spend_rank && bloodsucker_level_unspent <= 0)
			return
		// Did you choose a power?
		if(!choice || !options[choice])
			to_chat(owner.current, span_notice("You prevent your blood from thickening just yet, but you may try again later."))
			return
		if(power_mode != PURCHASE_TREMERE)
			// Prevent Bloodsuckers from closing/reopning their coffin to spam Levels.
			if((locate(options[choice]) in (power_mode == PURCHASE_VASSAL ? vassaldatum.powers : powers)))
				to_chat(owner.current, span_notice("You prevent your blood from thickening just yet, but you may try again later."))
				return
		if(power_mode != PURCHASE_VASSAL)
			// Prevent Bloodsuckers from purchasing a power while outside of their Coffin.
			if(!istype(owner.current.loc, /obj/structure/closet/crate/coffin))
				to_chat(owner.current, span_warning("You must be in your Coffin to purchase Powers."))
				return

		// Good to go - Buy Power!
		var/datum/action/cooldown/bloodsucker/purchased_power = options[choice]
		switch(power_mode)
			if(PURCHASE_DEFAULT)
				BuyPower(new purchased_power)
				owner.current.balloon_alert(owner.current, "learned [choice]!")
				to_chat(owner.current, span_notice("You have learned how to use [choice]!"))
			if(PURCHASE_VASSAL)
				vassaldatum.BuyPower(new purchased_power)
				owner.current.balloon_alert(owner.current, "taught [choice]!")
				to_chat(owner.current, span_notice("You taught [target] how to use [choice]!"))
				target.balloon_alert(target, "learned [choice]!")
				to_chat(target, span_notice("Your master taught you how to use [choice]!"))
			if(PURCHASE_TREMERE)
				var/datum/action/cooldown/bloodsucker/targeted/tremere/tremere_power = purchased_power
				if(isnull(tremere_power.upgraded_power))
					owner.current.balloon_alert(owner.current, "cannot upgrade [choice]!")
					to_chat(owner.current, span_notice("[choice] is already at max level!"))
					return
				BuyPower(new tremere_power.upgraded_power)
				RemovePower(tremere_power)
				owner.current.balloon_alert(owner.current, "upgraded [choice]!")
				to_chat(owner.current, span_notice("You have upgraded [choice]!"))

	// Advance Powers - Includes the one you just purchased.
	LevelUpPowers()
	vassaldatum?.LevelUpPowers()
	// Bloodsucker-only Stat upgrades
	bloodsucker_regen_rate += 0.05
	max_blood_volume += 100
	// Misc. Stats Upgrades
	if(ishuman(owner.current))
		var/mob/living/carbon/human/user = owner.current
		var/datum/species/user_species = user.dna.species
		user_species.punchdamagelow += 0.5
		// This affects the hitting power of Brawn.
		user_species.punchdamagehigh += 0.5

	// We're almost done - Spend your Rank now.
	vassaldatum?.vassal_level++
	bloodsucker_level++
	if(spend_rank)
		bloodsucker_level_unspent--
	if(spend_blood)
		bloodsucker_blood_volume -= 550

	// Ranked up enough? Let them join a Clan.
	if(bloodsucker_level == 3)
		AssignClanAndBane()
	// Ranked up enough to get your true Reputation?
	if(bloodsucker_level == 4)
		SelectReputation(am_fledgling = FALSE, forced = TRUE)
	if(power_mode == PURCHASE_VASSAL)
		if(vassaldatum.vassal_level == 2)
			ADD_TRAIT(target, TRAIT_COLDBLOODED, BLOODSUCKER_TRAIT)
			ADD_TRAIT(target, TRAIT_NOBREATH, BLOODSUCKER_TRAIT)
			ADD_TRAIT(target, TRAIT_AGEUSIA, BLOODSUCKER_TRAIT)
			to_chat(target, span_notice("Your blood begins to feel cold, and as a mote of ash lands upon your tongue, you stop breathing..."))
		if(vassaldatum.vassal_level == 3)
			ADD_TRAIT(target, TRAIT_NOCRITDAMAGE, BLOODSUCKER_TRAIT)
			ADD_TRAIT(target, TRAIT_NOSOFTCRIT, BLOODSUCKER_TRAIT)
			to_chat(target, span_notice("You feel your Master's blood reinforce you, strengthening you up."))
		if(vassaldatum.vassal_level == 4)
			ADD_TRAIT(target, TRAIT_SLEEPIMMUNE, BLOODSUCKER_TRAIT)
			ADD_TRAIT(target, TRAIT_VIRUSIMMUNE, BLOODSUCKER_TRAIT)
			to_chat(target, span_notice("You feel your Master's blood begin to protect you from bacteria."))
			target.skin_tone = "albino"
		if(vassaldatum.vassal_level == 5)
			ADD_TRAIT(target, TRAIT_NOHARDCRIT, BLOODSUCKER_TRAIT)
			ADD_TRAIT(target, TRAIT_HARDLY_WOUNDED, BLOODSUCKER_TRAIT)
			to_chat(target, span_notice("You feel yourself able to take cuts and stabbings like it's nothing."))
		if(vassaldatum.vassal_level == 6)
			to_chat(target, span_notice("You feel your heart stop pumping for the last time as you begin to thirst for blood, you feel... dead."))
			target.mind.add_antag_datum(/datum/antagonist/bloodsucker)
			SEND_SIGNAL(owner.current, COMSIG_ADD_MOOD_EVENT, "madevamp", /datum/mood_event/madevamp)
		if(vassaldatum.vassal_level >= 6) // We're a Bloodsucker now, lets update our Rank hud from now on.
			set_vassal_level(target)

	// Done! Let them know & Update their HUD.
	to_chat(owner.current, span_notice("You are now a rank [bloodsucker_level] Bloodsucker. Your strength, health, feed rate, regen rate, and maximum blood capacity have all increased!\n\
	* Your existing powers have all ranked up as well!"))
	update_hud()
	owner.current.playsound_local(null, 'sound/effects/pope_entry.ogg', 25, TRUE, pressure_affected = FALSE)

#undef PURCHASE_VASSAL
#undef PURCHASE_TREMERE
#undef PURCHASE_DEFAULT

///Set the Vassal's rank to their Bloodsucker level
/datum/antagonist/bloodsucker/proc/set_vassal_level(mob/living/carbon/human/target)
	var/datum/antagonist/bloodsucker/bloodsuckerdatum = IS_BLOODSUCKER(target)
	var/datum/antagonist/vassal/vassaldatum = IS_VASSAL(target)
	bloodsuckerdatum.bloodsucker_level = vassaldatum.vassal_level

////////////////////////////////////////////////////////////////////////////////////////////////

/datum/antagonist/bloodsucker/proc/forge_bloodsucker_objectives()

	// Claim a Lair Objective
	var/datum/objective/bloodsucker/lair/lair_objective = new
	lair_objective.owner = owner
	objectives += lair_objective

	// Survive Objective
	var/datum/objective/survive/bloodsucker/survive_objective = new
	survive_objective.owner = owner
	objectives += survive_objective

	// Objective 1: Vassalize a Head/Command, or a specific target
	switch(rand(1,3))
		if(1) // Conversion Objective
			var/datum/objective/bloodsucker/conversion/chosen_subtype = pick(subtypesof(/datum/objective/bloodsucker/conversion))
			var/datum/objective/bloodsucker/conversion/conversion_objective = new chosen_subtype
			conversion_objective.owner = owner
			conversion_objective.objective_name = "Optional Objective"
			objectives += conversion_objective
		if(2) // Heart Thief Objective
			var/datum/objective/bloodsucker/heartthief/heartthief_objective = new
			heartthief_objective.owner = owner
			heartthief_objective.objective_name = "Optional Objective"
			objectives += heartthief_objective
		if(3) // Drink Blood Objective
			var/datum/objective/bloodsucker/gourmand/gourmand_objective = new
			gourmand_objective.owner = owner
			gourmand_objective.objective_name = "Optional Objective"
			objectives += gourmand_objective


/// Name shown on antag list
/datum/antagonist/bloodsucker/antag_listing_name()
	return ..() + "([ReturnFullName(TRUE)])"

/// Whatever interesting things happened to the antag admins should know about
/// Include additional information about antag in this part
/datum/antagonist/bloodsucker/antag_listing_status()
	if(owner && !considered_alive(owner))
		return "<font color=red>Final Death</font>"
	return ..()

/*
 *	# Bloodsucker Names
 *
 *	All Bloodsuckers get a name, and gets a better one when they hit Rank 4.
 */

/// Names
/datum/antagonist/bloodsucker/proc/SelectFirstName()
	if(owner.current.gender == MALE)
		bloodsucker_name = pick(
			"Desmond","Rudolph","Dracula","Vlad","Pyotr","Gregor",
			"Cristian","Christoff","Marcu","Andrei","Constantin",
			"Gheorghe","Grigore","Ilie","Iacob","Luca","Mihail","Pavel",
			"Vasile","Octavian","Sorin","Sveyn","Aurel","Alexe","Iustin",
			"Theodor","Dimitrie","Octav","Damien","Magnus","Caine","Abel", // Romanian/Ancient
			"Lucius","Gaius","Otho","Balbinus","Arcadius","Romanos","Alexios","Vitellius", // Latin
			"Melanthus","Teuthras","Orchamus","Amyntor","Axion", // Greek
			"Thoth","Thutmose","Osorkon,","Nofret","Minmotu","Khafra", // Egyptian
			"Dio",
		)
	else
		bloodsucker_name = pick(
			"Islana","Tyrra","Greganna","Pytra","Hilda",
			"Andra","Crina","Viorela","Viorica","Anemona",
			"Camelia","Narcisa","Sorina","Alessia","Sophia",
			"Gladda","Arcana","Morgan","Lasarra","Ioana","Elena",
			"Alina","Rodica","Teodora","Denisa","Mihaela",
			"Svetla","Stefania","Diyana","Kelssa","Lilith", // Romanian/Ancient
			"Alexia","Athanasia","Callista","Karena","Nephele","Scylla","Ursa", // Latin
			"Alcestis","Damaris","Elisavet","Khthonia","Teodora", // Greek
			"Nefret","Ankhesenpep", // Egyptian
		)

/datum/antagonist/bloodsucker/proc/SelectTitle(am_fledgling = 0, forced = FALSE)
	// Already have Title
	if(!forced && bloodsucker_title != null)
		return
	// Titles [Master]
	if(!am_fledgling)
		if(owner.current.gender == MALE)
			bloodsucker_title = pick ("Count","Baron","Viscount","Prince","Duke","Tzar","Dreadlord","Lord","Master")
		else
			bloodsucker_title = pick ("Countess","Baroness","Viscountess","Princess","Duchess","Tzarina","Dreadlady","Lady","Mistress")
		to_chat(owner, span_announce("You have earned a title! You are now known as <i>[ReturnFullName(TRUE)]</i>!"))
	// Titles [Fledgling]
	else
		bloodsucker_title = null

/datum/antagonist/bloodsucker/proc/SelectReputation(am_fledgling = FALSE, forced = FALSE)
	// Already have Reputation
	if(!forced && bloodsucker_reputation != null)
		return

	if(am_fledgling)
		bloodsucker_reputation = pick(
			"Crude","Callow","Unlearned","Neophyte","Novice","Unseasoned",
			"Fledgling","Young","Neonate","Scrapling","Untested","Unproven",
			"Unknown","Newly Risen","Born","Scavenger","Unknowing","Unspoiled",
			"Disgraced","Defrocked","Shamed","Meek","Timid","Broken","Fresh",
		)
	else if(owner.current.gender == MALE && prob(10))
		bloodsucker_reputation = pick("King of the Damned", "Blood King", "Emperor of Blades", "Sinlord", "God-King")
	else if(owner.current.gender == FEMALE && prob(10))
		bloodsucker_reputation = pick("Queen of the Damned", "Blood Queen", "Empress of Blades", "Sinlady", "God-Queen")
	else
		bloodsucker_reputation = pick(
			"Butcher","Blood Fiend","Crimson","Red","Black","Terror",
			"Nightman","Feared","Ravenous","Fiend","Malevolent","Wicked",
			"Ancient","Plaguebringer","Sinister","Forgotten","Wretched","Baleful",
			"Inqisitor","Harvester","Reviled","Robust","Betrayer","Destructor",
			"Damned","Accursed","Terrible","Vicious","Profane","Vile",
			"Depraved","Foul","Slayer","Manslayer","Sovereign","Slaughterer",
			"Forsaken","Mad","Dragon","Savage","Villainous","Nefarious",
			"Inquisitor","Marauder","Horrible","Immortal","Undying","Overlord",
			"Corrupt","Hellspawn","Tyrant","Sanguineous",
		)

	to_chat(owner, span_announce("You have earned a reputation! You are now known as <i>[ReturnFullName(TRUE)]</i>!"))

/datum/antagonist/bloodsucker/proc/ReturnFullName(include_rep = FALSE)

	var/fullname
	// Name First
	fullname = (bloodsucker_name ? bloodsucker_name : owner.current.name)
	// Title
	if(bloodsucker_title)
		fullname = bloodsucker_title + " " + fullname
	// Rep
	if(include_rep && bloodsucker_reputation)
		fullname = fullname + " the " + bloodsucker_reputation

	return fullname

///When a Bloodsucker breaks the Masquerade, they get their HUD icon changed, and Malkavian Bloodsuckers get alerted.
/datum/antagonist/bloodsucker/proc/break_masquerade()
	if(broke_masquerade)
		return
	owner.current.playsound_local(null, 'fulp_modules/features/antagonists/bloodsuckers/sounds/lunge_warn.ogg', 100, FALSE, pressure_affected = FALSE)
	to_chat(owner.current, span_cultboldtalic("You have broken the Masquerade!"))
	to_chat(owner.current, span_warning("Bloodsucker Tip: When you break the Masquerade, you become open for termination by fellow Bloodsuckers, and your Vassals are no longer completely loyal to you, as other Bloodsuckers can steal them for themselves!"))
	broke_masquerade = TRUE
	antag_hud_name = "masquerade_broken"
	add_team_hud(owner.current)
	for(var/datum/mind/clan_minds as anything in get_antag_minds(/datum/antagonist/bloodsucker))
		if(owner == clan_minds)
			continue
		if(!isliving(clan_minds.current))
			continue
		to_chat(clan_minds, span_userdanger("[owner.current] has broken the Masquerade! Ensure [owner.current.p_they()] [owner.current.p_are()] eliminated at all costs!"))
		var/datum/antagonist/bloodsucker/bloodsuckerdatum = clan_minds.has_antag_datum(/datum/antagonist/bloodsucker)
		if(bloodsuckerdatum.my_clan != CLAN_MALKAVIAN)
			continue
		var/datum/objective/assassinate/masquerade_objective = new /datum/objective/assassinate
		masquerade_objective.target = owner.current
		masquerade_objective.objective_name = "Clan Objective"
		masquerade_objective.explanation_text = "Ensure [owner.current], who has broken the Masquerade, succumbs to Final Death."
		bloodsuckerdatum.objectives += masquerade_objective
		clan_minds.announce_objectives()

///This is admin-only of reverting a broken masquerade, sadly it doesn't remove the Malkavian objectives yet.
/datum/antagonist/bloodsucker/proc/fix_masquerade()
	if(!broke_masquerade)
		return
	to_chat(owner.current, span_cultboldtalic("You have re-entered the Masquerade."))
	broke_masquerade = FALSE


/////////////////////////////////////
//  BLOOD COUNTER & RANK MARKER !  //
/////////////////////////////////////

/atom/movable/screen/bloodsucker
	icon = 'fulp_modules/features/antagonists/bloodsuckers/icons/actions_bloodsucker.dmi'

///Updates the counter on said HUD
/atom/movable/screen/bloodsucker/proc/update_counter()

/atom/movable/screen/bloodsucker/blood_counter
	name = "Blood Consumed"
	icon_state = "blood_display"
	screen_loc = ui_blood_display

/atom/movable/screen/bloodsucker/rank_counter
	name = "Bloodsucker Rank"
	icon_state = "rank"
	screen_loc = ui_vamprank_display

/atom/movable/screen/bloodsucker/sunlight_counter
	name = "Solar Flare Timer"
	icon_state = "sunlight_night"
	screen_loc = ui_sunlight_display

/// Update Blood Counter + Rank Counter
/datum/antagonist/bloodsucker/proc/update_hud()
	var/valuecolor
	if(bloodsucker_blood_volume > BLOOD_VOLUME_SAFE)
		valuecolor = "#FFDDDD"
	else if(bloodsucker_blood_volume > BLOOD_VOLUME_BAD)
		valuecolor = "#FFAAAA"

	if(blood_display)
		blood_display.update_counter(bloodsucker_blood_volume, valuecolor)

	if(vamprank_display)
		if(bloodsucker_level_unspent > 0)
			vamprank_display.icon_state = "rank_up"
		else
			vamprank_display.icon_state = "rank"
		vamprank_display.update_counter(bloodsucker_level, valuecolor)

/// Update Sun Time
/datum/antagonist/bloodsucker/proc/update_sunlight(value, amDay = FALSE)
	if(!sunlight_display)
		return
	var/valuecolor
	var/sunlight_display_icon = "sunlight_"
	if(amDay)
		sunlight_display_icon += "day"
		valuecolor = "#FF5555"
	else
		switch(round(value, 1))
			if(0 to 30)
				sunlight_display_icon += "30"
				valuecolor = "#FFCCCC"
			if(31 to 60)
				sunlight_display_icon += "60"
				valuecolor = "#FFE6CC"
			if(61 to 90)
				sunlight_display_icon += "90"
				valuecolor = "#FFFFCC"
			else
				sunlight_display_icon += "night"
				valuecolor = "#FFFFFF"

	var/value_string = (value >= 60) ? "[round(value / 60, 1)] m" : "[round(value, 1)] s"
	sunlight_display.update_counter(value_string, valuecolor)
	sunlight_display.icon_state = sunlight_display_icon

/atom/movable/screen/bloodsucker/blood_counter/update_counter(value, valuecolor)
	. = ..()
	maptext = FORMAT_BLOODSUCKER_HUD_TEXT(valuecolor, value)

/atom/movable/screen/bloodsucker/rank_counter/update_counter(value, valuecolor)
	. = ..()
	maptext = FORMAT_BLOODSUCKER_HUD_TEXT(valuecolor, value)

/atom/movable/screen/bloodsucker/sunlight_counter/update_counter(value, valuecolor)
	. = ..()
	maptext = FORMAT_BLOODSUCKER_SUNLIGHT_TEXT(valuecolor, value)
