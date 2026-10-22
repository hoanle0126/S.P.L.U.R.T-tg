/datum/quirk_constant_data/egg_production
	associated_typepath = /datum/quirk/egg_production
	customization_options = list(
		/datum/preference/numeric/oviparity_max_eggs,
		/datum/preference/numeric/oviparity_production_rate,
	)

/datum/preference/numeric/oviparity_max_eggs
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_key = "oviparity_max_eggs"
	savefile_identifier = PREFERENCE_CHARACTER
	step = 5
	minimum = 5
	maximum = 100

/datum/preference/numeric/oviparity_max_eggs/create_default_value()
	return 100

/datum/preference/numeric/oviparity_max_eggs/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return FALSE

/datum/preference/numeric/oviparity_production_rate
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_key = "oviparity_production_rate"
	savefile_identifier = PREFERENCE_CHARACTER
	step = 1
	minimum = 5
	maximum = 60

/datum/preference/numeric/oviparity_production_rate/create_default_value()
	return 10

/datum/preference/numeric/oviparity_production_rate/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return FALSE

/datum/quirk/egg_production/add(client/client_source)
	var/mob/living/carbon/human/human_holder = quirk_holder
	var/datum/action/cooldown/spell/egg_production/action = new /datum/action/cooldown/spell/egg_production()
	if(client_source?.prefs)
		action.maximum_eggs = client_source.prefs.read_preference(/datum/preference/numeric/oviparity_max_eggs)
		action.production_rate = client_source.prefs.read_preference(/datum/preference/numeric/oviparity_production_rate) SECONDS
	action.Grant(human_holder)

/datum/action/cooldown/spell/egg_production
	/// Configurable cooldown between egg production ticks for cum
	var/production_rate = 10 SECONDS
	/// Tracks whether the active cum dose came from an allowed climax orifice (null when no active climax dose)
	var/last_insemination_valid = null

/datum/action/cooldown/spell/egg_production/create_egg(datum/reagent/reagent)
	if(!can_produce)
		return FALSE //cooldown is active, abort the proc

	var/mob/living/carbon/human/egg_holder = owner
	var/list/cached_reagents = egg_holder.reagents?.reagent_list
	if(!length(cached_reagents))
		last_insemination_valid = null
		return FALSE //there were no reagents, abort the proc

	if(eggs_stored >= maximum_eggs)
		return FALSE //we are at the maximum storable eggs, abort the proc

	var/client/pref_client = GET_CLIENT(egg_holder)
	var/has_active_cum = FALSE
	for(var/datum/reagent/target_reagent as anything in cached_reagents)
		if(target_reagent.name == "cum" && target_reagent.volume >= egg_production_reagents["cum"][1])
			has_active_cum = TRUE
			break
	if(!has_active_cum)
		last_insemination_valid = null

	for(var/datum/reagent/target_reagent as anything in cached_reagents)
		if(!(target_reagent.name in egg_production_reagents)) // checks to ensure the target reagent is even correct, this was a pain in the ass
			continue
		if(target_reagent.volume >= egg_production_reagents[target_reagent.name][1])
			var/cooldown = egg_production_reagents[target_reagent.name][2]
			if(target_reagent.name == "cum")
				cooldown = production_rate
				if(HAS_TRAIT(egg_holder, TRAIT_INFERTILE) || last_insemination_valid == FALSE)
					continue
				if(pref_client?.prefs)
					if(isnull(last_insemination_valid) && !pref_client.prefs.read_preference(/datum/preference/toggle/pregnancy/oral_insemination))
						continue
					if(!prob(pref_client.prefs.read_preference(/datum/preference/numeric/pregnancy/chance)))
						toggle_cooldown()
						addtimer(CALLBACK(src, PROC_REF(toggle_cooldown)), cooldown)
						return FALSE
			var/egg_thought = pick(possible_egg_thoughts)
			to_chat(owner, span_notice("[egg_thought]"))
			egg_update(1, egg_holder)
			toggle_cooldown()
			addtimer(CALLBACK(src, PROC_REF(toggle_cooldown)), cooldown)
			return TRUE //completed once, now kill the entire proc
	return

/datum/action/cooldown/spell/egg_production/cast(mob/living/cast_on)
	SHOULD_CALL_PARENT(FALSE)
	SEND_SIGNAL(src, COMSIG_SPELL_CAST, cast_on)
	if(owner)
		SEND_SIGNAL(owner, COMSIG_MOB_CAST_SPELL, src, cast_on)
		if(owner.ckey)
			owner.log_message("cast the spell [name][cast_on != owner ? " on / at [cast_on]":""].", LOG_ATTACK)
	if(eggs_stored <= 0)
		owner.balloon_alert(owner, "no eggs to lay!")
		return FALSE

	to_chat(owner, span_noticealien("You start laying an egg..."))
	if(!do_after(owner, 2 SECONDS, cast_on, IGNORE_HELD_ITEM))
		owner.balloon_alert(owner, "stopped attempting to lay an egg.")
		return FALSE

	egg_update(-1) //decrements the stored eggs by 1
	egg = new(owner)
	owner.put_in_hands(egg)
	owner.visible_message(span_noticealien("[owner] laid an egg!"), span_alertalien("You laid an egg!"))
	return TRUE
