// Because we can control each corner of every lighting object.
// And corners get shared between multiple turfs (unless you're on the corners of the map, then 1 corner doesn't).
// For the record: these should never ever ever be deleted, even if the turf doesn't have dynamic lighting.

/datum/lighting_corner
	var/list/datum/light_source/affecting // Light sources affecting us.

	var/x     = 0
	var/y     = 0

	var/turf/master_NE
	var/turf/master_SE
	var/turf/master_SW
	var/turf/master_NW

	var/lum_r = 0
	var/lum_g = 0
	var/lum_b = 0

	var/needs_update = FALSE

	var/cache_r  = LIGHTING_SOFT_THRESHOLD
	var/cache_g  = LIGHTING_SOFT_THRESHOLD
	var/cache_b  = LIGHTING_SOFT_THRESHOLD
	var/cache_mx = 0

/datum/lighting_corner/New(turf/new_turf, diagonal)
	. = ..()
	save_master(new_turf, turn(diagonal, 180))

	var/vertical   = diagonal & ~(diagonal - 1) // The horizontal directions (4 and 8) are bigger than the vertical ones (1 and 2), so we can reliably say the lsb is the horizontal direction.
	var/horizontal = diagonal & ~vertical       // Now that we know the horizontal one we can get the vertical one.

	x = new_turf.x + (horizontal == EAST  ? 0.5 : -0.5)
	y = new_turf.y + (vertical   == NORTH ? 0.5 : -0.5)

	// My initial plan was to make this loop through a list of all the dirs (horizontal, vertical, diagonal).
	// Issue being that the only way I could think of doing it was very messy, slow and honestly overengineered.
	// So we'll have this hardcode instead.
	var/turf/T

	// Diagonal one is easy.
	T = get_step(new_turf, diagonal)
	if (T) // In case we're on the map's border.
		save_master(T, diagonal)

	// Now the horizontal one.
	T = get_step(new_turf, horizontal)
	if (T) // Ditto.
		save_master(T, ((T.x > x) ? EAST : WEST) | ((T.y > y) ? NORTH : SOUTH)) // Get the dir based on coordinates.

	// And finally the vertical one.
	T = get_step(new_turf, vertical)
	if (T)
		save_master(T, ((T.x > x) ? EAST : WEST) | ((T.y > y) ? NORTH : SOUTH)) // Get the dir based on coordinates.

/datum/lighting_corner/proc/save_master(turf/master, dir)
	switch (dir)
		if (NORTHEAST)
			master_NE = master
			master.lighting_corner_SW = src
		if (SOUTHEAST)
			master_SE = master
			master.lighting_corner_NW = src
		if (SOUTHWEST)
			master_SW = master
			master.lighting_corner_NE = src
		if (NORTHWEST)
			master_NW = master
			master.lighting_corner_SE = src

/datum/lighting_corner/proc/self_destruct_if_idle()
	if (!length(affecting))
		qdel(src, force = TRUE)

/datum/lighting_corner/proc/vis_update()
	for (var/datum/light_source/light_source as anything in affecting)
		light_source.vis_update()

/datum/lighting_corner/proc/full_update()
	for (var/datum/light_source/light_source as anything in affecting)
		light_source.recalc_corner(src)

// God that was a mess, now to do the rest of the corner code! Hooray!
/datum/lighting_corner/proc/update_lumcount(delta_r, delta_g, delta_b)
	if (!(delta_r || delta_g || delta_b)) // 0 is falsey ok
		return

	lum_r += delta_r
	lum_g += delta_g
	lum_b += delta_b

	if (!needs_update)
		needs_update = TRUE
		SSlighting.corners_queue += src

/datum/lighting_corner/proc/update_objects()
	// Cache these values ahead of time so 4 individual lighting objects don't all calculate them individually.
	var/lum_r = src.lum_r
	var/lum_g = src.lum_g
	var/lum_b = src.lum_b
	var/mx = max(lum_r, lum_g, lum_b) // Scale it so one of them is the strongest lum, if it is above 1.
	. = 1 // factor
	if (mx > 1)
		. = 1 / mx

	#if LIGHTING_SOFT_THRESHOLD != 0
	else if (mx < LIGHTING_SOFT_THRESHOLD)
		. = 0 // 0 means soft lighting.

	cache_r  = round(lum_r * ., LIGHTING_ROUND_VALUE) || LIGHTING_SOFT_THRESHOLD
	cache_g  = round(lum_g * ., LIGHTING_ROUND_VALUE) || LIGHTING_SOFT_THRESHOLD
	cache_b  = round(lum_b * ., LIGHTING_ROUND_VALUE) || LIGHTING_SOFT_THRESHOLD
	#else
	cache_r  = round(lum_r * ., LIGHTING_ROUND_VALUE)
	cache_g  = round(lum_g * ., LIGHTING_ROUND_VALUE)
	cache_b  = round(lum_b * ., LIGHTING_ROUND_VALUE)
	#endif
	cache_mx = round(mx, LIGHTING_ROUND_VALUE)

	var/atom/movable/lighting_object/lighting_object
	var/area/master_area

	// currently we spawn lighting_object's on demand, but don't delete them after for future reuse

	if(master_NE)
		master_area = master_NE.loc
		if(master_area.dynamic_lighting)
			lighting_object = master_NE.lighting_object || new /atom/movable/lighting_object(master_NE)
			if (!lighting_object.needs_update)
				lighting_object.needs_update = TRUE
				SSlighting.objects_queue += lighting_object

	if(master_SE)
		master_area = master_SE.loc
		if(master_area.dynamic_lighting)
			lighting_object = master_SE.lighting_object || new /atom/movable/lighting_object(master_SE)
			if (!lighting_object.needs_update)
				lighting_object.needs_update = TRUE
				SSlighting.objects_queue += lighting_object

	if(master_SW)
		master_area = master_SW.loc
		if(master_area.dynamic_lighting)
			lighting_object = master_SW.lighting_object || new /atom/movable/lighting_object(master_SW)
			if (!lighting_object.needs_update)
				lighting_object.needs_update = TRUE
				SSlighting.objects_queue += lighting_object

	if(master_NW)
		master_area = master_NW.loc
		if(master_area.dynamic_lighting)
			lighting_object = master_NW.lighting_object || new /atom/movable/lighting_object(master_NW)
			if (!lighting_object.needs_update)
				lighting_object.needs_update = TRUE
				SSlighting.objects_queue += lighting_object

	self_destruct_if_idle()

/datum/lighting_corner/dummy/New()
	return

/datum/lighting_corner/Destroy(force)
	if (!force)
		return QDEL_HINT_LETMELIVE

	for (var/datum/light_source/light_source as anything in affecting)
		LAZYREMOVE(light_source.effect_str, src)
	affecting = null

	if (master_NE)
		master_NE.lighting_corner_SW = null
		master_NE.lighting_corners_initialised = FALSE
	if (master_SE)
		master_SE.lighting_corner_NW = null
		master_SE.lighting_corners_initialised = FALSE
	if (master_SW)
		master_SW.lighting_corner_NE = null
		master_SW.lighting_corners_initialised = FALSE
	if (master_NW)
		master_NW.lighting_corner_SE = null
		master_NW.lighting_corners_initialised = FALSE
	if (needs_update)
		SSlighting.corners_queue -= src

	return ..()