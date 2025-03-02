/datum/action/cooldown/bloodsucker/brujah
	name = "Frenzy"
	desc = "Allow the Monster deep-inside of you, run free."
	button_icon_state = "power_brujah"
	power_explanation = "<b>Frenzy</b>:\n\
		A Brujah only Power. Activating it will make you enter a Frenzy.\n\
		When in a Frenzy, you get extra stun resistance, slowly gain brute damage, move faster, become mute/deaf,\n\
		and become unable to use complicated machinery as your screen goes blood-red."
	power_flags = BP_AM_TOGGLE|BP_AM_STATIC_COOLDOWN|BP_AM_COSTLESS_UNCONSCIOUS
	check_flags = NONE
	purchase_flags = NONE
	bloodcost = 2
	cooldown = 10 SECONDS

/datum/action/cooldown/bloodsucker/brujah/ActivatePower()
	if(active && bloodsuckerdatum_power && bloodsuckerdatum_power.frenzied)
		owner.balloon_alert(owner, "already in a frenzy!")
		return FALSE
	var/mob/living/user = owner
	user.apply_status_effect(/datum/status_effect/frenzy)
	return ..()

/datum/action/cooldown/bloodsucker/brujah/DeactivatePower()
	. = ..()
	var/mob/living/user = owner
	user.remove_status_effect(/datum/status_effect/frenzy)

/datum/action/cooldown/bloodsucker/brujah/CheckCanDeactivate()
	if(bloodsuckerdatum_power.bloodsucker_blood_volume < FRENZY_THRESHOLD_EXIT)
		owner.balloon_alert(owner, "not enough blood!")
		return FALSE
	return ..()
