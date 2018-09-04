#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <fakemeta_util>
#include <engine>
#include <fun>
#include <hamsandwich>
#include <xs>

#define PLUGIN "ãê×£/Shenron/Than Long"
#define VERSION "1.0"
#define AUTHOR "Sneaky.amxx"

#define VANISH_TIME 30.0 // Vanish time must be lower than AppearTime
#define DECISION_DELAY 3.0

#define RYUU_CLASSNAME "doragon"
#define BALL_CLASSNAME "suigintou"
#define BALL2_CLASSNAME "shinku"

new const Model[] = "models/shenron.mdl"
new const Sound[9][] =
{
	"shenron/end_attack.wav", // USE
	"shenron/energy_loop_loud_original.wav",
	"shenron/energy_loop_quiet.wav", // USE
	"shenron/energy_start_loud_original.wav",
	"shenron/energy_start_quiet.wav", // USE
	"shenron/spawn_location.wav", // USE
	"shenron/start_attack.wav", // USE
	"shenron/vanish.wav", // USE
	"shenron/wish_granted.wav" // USE
}

new const DragonBall[8][] =
{
	"models/dragonball_all.mdl",
	"models/dragonball_1.mdl",
	"models/dragonball_2.mdl",
	"models/dragonball_3.mdl",
	"models/dragonball_4.mdl",
	"models/dragonball_5.mdl",
	"models/dragonball_6.mdl",
	"models/dragonball_7.mdl"
}

new const BallSound[2][] =
{
	"dragonballs/db_glowing.wav",
	"dragonballs/db_flying.wav"
}

new Saigon[8]
new const SPAWNS_URL[] = "%s/shenron/%s.suigintou"

const MAX_SPAWNS = 128
const MAX_POINTS = 32

new g_spawns[MAX_SPAWNS][3], g_total_spawns, g_spawn_edit, g_spawns_r[MAX_SPAWNS][3]
new g_UsedSpawn[MAX_SPAWNS]

new cache_spr_line
new const color_spawn_bot[3] = {255,255,255}
new const color_point_edit[3] = {162,17,237}

new jumpnum[33] = 0
new bool:dojump[33] = false

// Task offsets
enum (+= 100)
{
	TASK_SHOW_SPAWNS = 2000,
	TASK_SHOW_WAYS,
	TASK_SHOW_BOXS,
	TASK_DRAGON
}
// IDs inside tasks
#define ID_SHOW_SPAWNS (taskid - TASK_SHOW_SPAWNS)
#define ID_SHOW_WAYS (taskid - TASK_SHOW_WAYS)
#define ID_SHOW_BOXS (taskid - TASK_SHOW_BOXS)

new Long, g_sprite, g_MyBall[33]
new g_Has_Speed[33], g_Has_DoubleJump[33], g_Has_DoubleDamage[33]

//######################################################################
// REG PLUGIN
//######################################################################

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0")
	register_event("DeathMsg", "Event_Death", "a")
	register_touch(BALL_CLASSNAME, "player", "fw_BallTouch")
	register_think(BALL2_CLASSNAME, "fw_BallThink")
	
	spawn_load()
	register_think(RYUU_CLASSNAME, "fw_Think")
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage", 0)
	
	register_concmd("shenron", "menu_main")
}

public plugin_precache()
{
	precache_model(Model)
	for(new i = 0; i < sizeof(Sound); i++)
		precache_sound(Sound[i])
	for(new i = 0; i < sizeof(DragonBall); i++)
		precache_model(DragonBall[i])
	for(new i = 0; i < sizeof(BallSound); i++)
		precache_sound(BallSound[i])
		
	cache_spr_line = precache_model("sprites/laserbeam.spr")
	g_sprite = precache_model("sprites/beacon.spr")
}

public Event_NewRound()
{
	remove_task(Long)
	remove_entity_name(RYUU_CLASSNAME)
	remove_entity_name(BALL_CLASSNAME)
	remove_entity_name(BALL2_CLASSNAME)
	
	for(new i = 0; i < g_total_spawns; i++)
		g_UsedSpawn[i] = 0
	for(new i = 0; i < 8; i++)
		Saigon[i] = 0
	
	if(g_total_spawns >= 7)
		Create_DragonBall()
}

public client_putinserver(id)
{
	jumpnum[id] = 0
	dojump[id] = false
}

public client_disconnect(id)
{
	jumpnum[id] = 0
	dojump[id] = false
}

public Create_DragonBall()
{
	static SpawnID; 
	for(new i = 0; i < 7; i++)
	{
		SpawnID = random(g_total_spawns)
		while(g_UsedSpawn[SpawnID])
			SpawnID = random(g_total_spawns)
		g_UsedSpawn[SpawnID] = 1
		
		Create_Suigintou(i+1, SpawnID)
	}
}

public Create_Suigintou(Num, SpawnID)
{
	static Float:Origin[3], Ori[3]
	
	Ori = g_spawns[SpawnID]
	Origin[0] = float(Ori[0])
	Origin[1] = float(Ori[1])
	Origin[2] = float(Ori[2])
	
	static Ball; Ball = create_entity("info_target")
	set_pev(Ball, pev_origin, Origin)
	
	set_pev(Ball, pev_classname, BALL_CLASSNAME)
	engfunc(EngFunc_SetModel, Ball, DragonBall[Num])

	set_pev(Ball, pev_gamestate, 1)
	set_pev(Ball, pev_solid, SOLID_TRIGGER)
	set_pev(Ball, pev_movetype, MOVETYPE_PUSHSTEP)
	set_pev(Ball, pev_iuser1, Num)
	set_pev(Ball, pev_iuser2, 0)
	set_pev(Ball, pev_iuser3, 0)

	new Float:maxs[3] = {16.0, 16.0, 16.0}
	new Float:mins[3] = {-16.0, -16.0, -16.0}
	engfunc(EngFunc_SetSize, Ball, mins, maxs)
	
	fm_set_rendering(Ball, kRenderFxGlowShell, 0, 0, 0, kRenderTransAdd, 150)
	
	set_pev(Ball, pev_animtime, get_gametime())
	set_pev(Ball, pev_framerate, 1.0)
	set_pev(Ball, pev_sequence, 0)

	set_pev(Ball, pev_nextthink, get_gametime() + 0.1)
	drop_to_floor(Ball)
}

public Recreate_Ball(Num, Float:Origin[3])
{
	static Ball; Ball = create_entity("info_target")
	set_pev(Ball, pev_origin, Origin)
	
	set_pev(Ball, pev_classname, BALL_CLASSNAME)
	engfunc(EngFunc_SetModel, Ball, DragonBall[Num])

	set_pev(Ball, pev_gamestate, 1)
	set_pev(Ball, pev_solid, SOLID_TRIGGER)
	set_pev(Ball, pev_movetype, MOVETYPE_PUSHSTEP)
	set_pev(Ball, pev_iuser1, Num)
	set_pev(Ball, pev_iuser2, 0)
	set_pev(Ball, pev_iuser3, 0)

	new Float:maxs[3] = {16.0, 16.0, 16.0}
	new Float:mins[3] = {-16.0, -16.0, -16.0}
	engfunc(EngFunc_SetSize, Ball, mins, maxs)
	
	fm_set_rendering(Ball, kRenderFxGlowShell, 0, 0, 0, kRenderTransAdd, 150)
	
	set_pev(Ball, pev_animtime, get_gametime())
	set_pev(Ball, pev_framerate, 1.0)
	set_pev(Ball, pev_sequence, 0)

	set_pev(Ball, pev_nextthink, get_gametime() + 0.1)
	
	static Float:Vel[3]; 
	Vel[0] = random_float(150.0, 300.0)
	Vel[1] = random_float(150.0, 300.0)
	Vel[2] = random_float(20.0, 100.0)
	
	set_pev(Ball, pev_velocity, Vel)
}

public fw_BallTouch(Ent, id)
{
	if(!pev_valid(Ent)) return
	if(!is_user_alive(id)) return
	
	static BallID; BallID = pev(Ent, pev_iuser1) 
	Saigon[BallID] = id 
	
	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
	set_pev(Ent, pev_flags, FL_KILLME)
	
	emit_sound(id, CHAN_ITEM, "items/tr_kevlar.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	client_print(id, print_chat, "You picked up 'The %i-Ball'", BallID)
	
	// UPdate
	Update_SpecialAmmo(id, g_MyBall[id], 0)
	g_MyBall[id]++
	Update_SpecialAmmo(id, g_MyBall[id], 1)
}

public Update_SpecialAmmo(id, Ammo, On)
{
	static AmmoSprites[33], Color[3]
	format(AmmoSprites, sizeof(AmmoSprites), "number_%d", Ammo)

	switch(Ammo)
	{
		case 1..3: { Color[0] = 0; Color[1] = 200; Color[2] = 0; }
		case 4..5: { Color[0] = 200; Color[1] = 200; Color[2] = 0; }
		case 6..10: { Color[0] = 200; Color[1] = 0; Color[2] = 0; }
	}
	
	static MSG; if(!MSG) MSG = get_user_msgid("StatusIcon")
	
	message_begin(MSG_ONE_UNRELIABLE, MSG, {0,0,0}, id)
	write_byte(On)
	write_string(AmmoSprites)
	write_byte(Color[0]) // red
	write_byte(Color[1]) // green
	write_byte(Color[2]) // blue
	message_end()
}

public Event_Death()
{
	static Victim; Victim = read_data(2)
	static Float:Origin[3]; pev(Victim, pev_origin, Origin)
	
	for(new i = 0; i < 8; i++)
	{
		if(Saigon[i] == Victim)
		{
			Recreate_Ball(i, Origin)
			Saigon[i] = 0
		}
	}
	
	if(g_MyBall[Victim] > 0) Update_SpecialAmmo(Victim, g_MyBall[Victim], 0)
	g_MyBall[Victim] = 0
}

public fw_PlayerSpawn_Post(id)
{
	g_MyBall[id] = 0
	remove_task(id+333)
	g_Has_Speed[id] = g_Has_DoubleJump[id] = g_Has_DoubleDamage[id] = 0
}

public fw_TakeDamage(Victim, Inflictor, Attacker, Float:Damage)
{
	if(is_user_connected(Attacker) && g_Has_DoubleDamage[Attacker])
		SetHamParamFloat(4, Damage * 2.0)
}

public Make_FuckingDragon(Float:Origin[3])
{
	remove_entity_name(RYUU_CLASSNAME)
	
	// New
	Long = create_entity("info_target")
	
//	Origin[2] -= 26.0
	set_pev(Long, pev_origin, Origin)
	
	set_pev(Long, pev_classname, RYUU_CLASSNAME)
	engfunc(EngFunc_SetModel, Long, Model)
	set_pev(Long, pev_modelindex, engfunc(EngFunc_ModelIndex, Model))
		
	set_pev(Long, pev_gamestate, 1)
	set_pev(Long, pev_solid, SOLID_BBOX)
	set_pev(Long, pev_movetype, MOVETYPE_NONE)
	set_pev(Long, pev_iuser1, 0)
	set_pev(Long, pev_iuser2, 0)
	set_pev(Long, pev_iuser3, 0)

	new Float:maxs[3] = {120.0, 120.0, 360.0}
	new Float:mins[3] = {-120.0, -120.0, 0.0}
	engfunc(EngFunc_SetSize, Long, mins, maxs)
	
	fm_set_rendering(Long, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, 10)
	
	set_pev(Long, pev_animtime, get_gametime())
	set_pev(Long, pev_framerate, 1.0)
	set_pev(Long, pev_sequence, 0)
	
	emit_sound(Long, CHAN_BODY, Sound[5], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	emit_sound(Long, CHAN_ITEM, Sound[3], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	set_pev(Long, pev_fuser1, get_gametime() + VANISH_TIME)
	set_pev(Long, pev_fuser2, get_gametime() - 1.0)
	set_pev(Long, pev_nextthink, get_gametime() + 0.1)
	drop_to_floor(Long)
}

public client_PreThink(id)
{
	if(!is_user_alive(id)) return PLUGIN_CONTINUE
	if(!g_Has_DoubleJump[id]) return PLUGIN_CONTINUE
	
	new nbut = get_user_button(id)
	new obut = get_user_oldbutton(id)
	if((nbut & IN_JUMP) && !(get_entity_flags(id) & FL_ONGROUND) && !(obut & IN_JUMP))
	{
		if(jumpnum[id] < 2)
		{
			dojump[id] = true
			jumpnum[id]++
			return PLUGIN_CONTINUE
		}
	}
	if((nbut & IN_JUMP) && (get_entity_flags(id) & FL_ONGROUND))
	{
		jumpnum[id] = 0
		return PLUGIN_CONTINUE
	}
	return PLUGIN_CONTINUE
}

public client_PostThink(id)
{
	if(!is_user_alive(id))
		return
		
	static Button; Button = get_user_button(id)
	static OK; OK = 1
	if((Button & IN_USE))
	{
		for(new i = 1; i < 8; i++)
		{
			if(Saigon[i] != id)
			{
				OK = 0
				break
			}
		}
		
		if(OK)
		{
			for(new i = 0; i < 8; i++)
				Saigon[i] = 0
				
			Create_Shinku(id)
		}
	}
	
	if(pev_valid(Long) && pev(Long, pev_iuser2) == id)
	{
		set_pev(id, pev_maxspeed, 0.01)
		
		static Float:Origin2[3]; pev(Long, pev_origin, Origin2)
		Origin2[2] -= 380.0
		
		Aim_To(id, Origin2, 0.0, 0)
	} else {
		if(g_Has_Speed[id])
		{
			if(pev(id, pev_max_health) != 350.0) set_pev(id, pev_maxspeed, 350.0)
		}
		if(g_Has_DoubleJump[id])
		{
			if(dojump[id] == true)
			{
				new Float:velocity[3]	
				entity_get_vector(id,EV_VEC_velocity,velocity)
				velocity[2] = random_float(265.0,285.0)
				entity_set_vector(id,EV_VEC_velocity,velocity)
				dojump[id] = false
				return
			}
		}
	}

	if(Button & IN_USE)
	{
		if(!pev_valid(Long))
			return
		if(pev(Long, pev_iuser1))
			return
		if(entity_range(Long, id) > 380.0)
			return
		if(!can_see_fm(id, Long))
			return
		static Float:Time; pev(Long, pev_fuser1, Time)
		if(Time <= get_gametime())
			return
		
		static Float:Origin[3]; pev(Long, pev_origin, Origin)
		Origin[2] += 480.0
		if(!is_in_viewcone(id, Origin))
			return
			
		set_pev(Long, pev_iuser1, 1)
		set_pev(Long, pev_iuser2, id)
		
		set_pev(Long, pev_animtime, get_gametime())
		set_pev(Long, pev_framerate, 1.0)
		set_pev(Long, pev_sequence, 4)
		
		set_pev(Long, pev_fuser3, get_gametime() + DECISION_DELAY)
	}
}

public Create_Shinku(id)
{
	if(g_MyBall[id] > 0) Update_SpecialAmmo(id, g_MyBall[id], 0)
	g_MyBall[id] = 0
	
	static Float:Origin[3]; pev(id, pev_origin, Origin)
	
	// Create Shit
	static Ball; Ball = create_entity("info_target")
	set_pev(Ball, pev_origin, Origin)
	
	set_pev(Ball, pev_classname, BALL2_CLASSNAME)
	engfunc(EngFunc_SetModel, Ball, DragonBall[0])

	set_pev(Ball, pev_gamestate, 1)
	set_pev(Ball, pev_solid, SOLID_TRIGGER)
	set_pev(Ball, pev_movetype, MOVETYPE_PUSHSTEP)
	set_pev(Ball, pev_iuser1, 0)
	set_pev(Ball, pev_iuser2, 0)
	set_pev(Ball, pev_iuser3, 0)

	new Float:maxs[3] = {16.0, 16.0, 16.0}
	new Float:mins[3] = {-16.0, -16.0, -16.0}
	engfunc(EngFunc_SetSize, Ball, mins, maxs)
	
	fm_set_rendering(Ball, kRenderFxGlowShell, 0, 0, 0, kRenderTransAdd, 150)
	
	set_pev(Ball, pev_animtime, get_gametime())
	set_pev(Ball, pev_framerate, 1.0)
	set_pev(Ball, pev_sequence, 0)

	set_pev(Ball, pev_nextthink, get_gametime() + 0.1)
	drop_to_floor(Ball)
	
	emit_sound(Ball, CHAN_BODY, BallSound[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}

public fw_BallThink(Ent)
{
	if(!pev_valid(Ent))
		return
		
	static Stage; Stage = pev(Ent, pev_iuser1)
	static Float:Origin[3]; pev(Ent, pev_origin, Origin)
	switch(Stage)
	{
		case 0: {
			set_pev(Ent, pev_iuser1, 1)
			Beacon(Origin)
			
			set_pev(Ent, pev_nextthink, get_gametime() + 1.25)
		}
		case 1: {
			set_pev(Ent, pev_iuser1, 2)
			Beacon(Origin)
			set_pev(Ent, pev_nextthink, get_gametime() + 1.25)
		}
		case 2: {
			set_pev(Ent, pev_iuser1, 3)
			Beacon(Origin)
			set_pev(Ent, pev_nextthink, get_gametime() + 1.25)
		
			emit_sound(Ent, CHAN_BODY, BallSound[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		}
		case 3: {
			set_pev(Ent, pev_iuser1, 4)
			Beacon(Origin)
			set_pev(Ent, pev_nextthink, get_gametime() + 1.25)
		}
		case 4: {
			set_pev(Ent, pev_iuser1, 5)
			Beacon(Origin)
			set_pev(Ent, pev_nextthink, get_gametime() + 0.75)
			
			for(new i = 0; i < get_maxplayers(); i++)
			{
				if(!is_user_alive(i))
					continue
				if(entity_range(Ent, i) > 480.0)
					continue
					
				fuck_ent2(i, Origin, 1000.0)
			}
			emit_sound(Ent, CHAN_BODY, BallSound[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		}
		case 5: {
			//remove_entity(Ent)
			Make_FuckingDragon(Origin)
		}
	}
	
}

public Beacon(Float:origin[3])
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMCYLINDER)
	write_coord_f(origin[0])
	write_coord_f(origin[1])
	write_coord_f(origin[2])
	write_coord_f(origin[0])    
	write_coord_f(origin[1])    
	write_coord_f(origin[2] + 200)
	write_short(g_sprite)
	write_byte(0)       
	write_byte(1)        
	write_byte(6)
	write_byte(2)        
	write_byte(1)        
	write_byte(50)      
	write_byte(50)      
	write_byte(255)
	write_byte(200)
	write_byte(6)
	message_end()
}

public fw_Think(Ent)
{
	if(!pev_valid(Ent))
		return
		
	static Float:Time; pev(Ent, pev_fuser1, Time)
	if(Time <= get_gametime() && !pev(Long, pev_iuser1))
	{
		static Float:Amount; pev(Ent, pev_renderamt, Amount)
		
		if(Amount == 246.5) emit_sound(Ent, CHAN_ITEM, Sound[7], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)

		if(Amount > 0.0)
		{
			set_pev(Ent, pev_rendermode, kRenderTransAlpha)
			set_pev(Ent, pev_renderamt, Amount - 3.5)
		} else {
			remove_entity(Ent)
			
			remove_entity_name(BALL_CLASSNAME)
			remove_entity_name(BALL2_CLASSNAME)
			
			return
		}
		
		set_pev(Long, pev_nextthink, get_gametime() + 0.1)
		return
	}
	
	static Float:Amount; pev(Ent, pev_renderamt, Amount)
	static Float:Origin[3]
	if(Amount < 250.0)
	{
		static id; id = FindClosetEnemy(Ent, 1)
		if(is_user_alive(id))
		{
			pev(id, pev_origin, Origin)
			Aim_To(Ent, Origin, 2.0, 0)
		}
		
		set_pev(Ent, pev_rendermode, kRenderTransAlpha)
		set_pev(Ent, pev_renderamt, Amount + 20.0)
		
		set_pev(Long, pev_nextthink, get_gametime() + 0.1)
		return
	}
	
	static Float:Time2; pev(Ent, pev_fuser2, Time2)
	if(get_gametime() - 7.0 > Time2)
	{
		emit_sound(Long, CHAN_ITEM, Sound[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		set_pev(Ent, pev_fuser2, get_gametime())
	}
		
	static Inter, id;
	Inter = pev(Ent, pev_iuser1)
	id = pev(Ent, pev_iuser2)
		
	if(!Inter)
	{
		static id; id = FindClosetEnemy(Ent, 1)
		if(is_user_alive(id))
		{
			pev(id, pev_origin, Origin)
			Aim_To(Ent, Origin, 2.0, 0)
		}
	} else {
		if(is_user_alive(id))
		{
			pev(id, pev_origin, Origin)
			Aim_To(Ent, Origin, 2.0, 0)
			
			static Float:Time; pev(Ent, pev_fuser3, Time)
			if(Time <= get_gametime())
			{
				if(!pev(Ent, pev_iuser3))
				{
					if(random_num(0, 1) == 1)
					{
						set_pev(Long, pev_animtime, get_gametime())
						set_pev(Long, pev_framerate, 1.0)
						set_pev(Long, pev_sequence, 3)
						
						set_pev(id, pev_maxspeed, 270.0)
						set_pev(Ent, pev_iuser2, 0)
						emit_sound(Long, CHAN_ITEM, Sound[8], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
						
						Give_Item(id)
						set_pev(Long, pev_nextthink, get_gametime() + 5.0)
					} else { // KOROSU!
						set_pev(Long, pev_animtime, get_gametime())
						set_pev(Long, pev_framerate, 1.0)
						set_pev(Long, pev_sequence, 2)
						
						emit_sound(Long, CHAN_ITEM, Sound[6], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
						
						set_pev(Ent, pev_iuser2, 0)
						set_task(0.25, "KOROSU", id+333)
						set_task(1.00, "KOROSU2", Ent)
						
						set_pev(Long, pev_nextthink, get_gametime() + 2.5)
					}
					
					set_pev(Ent, pev_iuser3, 1)
					return
				}
			}
		} else {
			set_pev(Ent, pev_iuser1, 0)
			set_pev(Ent, pev_fuser1, get_gametime() - VANISH_TIME)
		}
	}
	
	static Float:Origin3[3], Float:Origin4[3]; 
	
	pev(Ent, pev_origin, Origin3); Origin3[2] += 390.0
	get_position(Ent, random_float(-450.0, 450.0), random_float(-450.0, 450.0), 0.0, Origin4)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMPOINTS)
	engfunc(EngFunc_WriteCoord, Origin3[0])
	engfunc(EngFunc_WriteCoord, Origin3[1])
	engfunc(EngFunc_WriteCoord, Origin3[2])
	engfunc(EngFunc_WriteCoord, Origin4[0])
	engfunc(EngFunc_WriteCoord, Origin4[1])
	engfunc(EngFunc_WriteCoord, Origin4[2])
	write_short(cache_spr_line)
	write_byte(0)	// starting frame
	write_byte(0)	// frame rate in 0.1's
	write_byte(10)	// life in 0.1's
	write_byte(10)	// line width in 0.1's
	write_byte(100)	// noise amplitude in 0.01's
	write_byte(42)	// Red
	write_byte(85)	// Green
	write_byte(255)	// Blue
	write_byte(255)	// brightness
	write_byte(25)	// scroll speed in 0.1's
	message_end()
		
	set_pev(Long, pev_nextthink, get_gametime() + 0.1)
}

stock get_position(ent, Float:forw, Float:right, Float:up, Float:vStart[])
{
	if(!pev_valid(ent))
		return
		
	static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	pev(ent, pev_origin, vOrigin)
	pev(ent, pev_view_ofs,vUp) //for player
	xs_vec_add(vOrigin,vUp,vOrigin)
	pev(ent, pev_angles, vAngle) // if normal entity ,use pev_angles
	
	vAngle[0] = 0.0
	
	angle_vector(vAngle,ANGLEVECTOR_FORWARD,vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle,ANGLEVECTOR_RIGHT,vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP,vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}

public Give_Item(id)
{
	switch(random_num(0, 7))
	{
		case 0:
		{
			client_print(id, print_chat, "Made by Sneaky.amxx QQ @ 1282743988")
			client_print(id, print_chat, "your wish gave you a random weapon")
			// Weapon
			switch(random_num(0, 2))
			{
				case 0: give_item(id, "weapon_ak47")
				case 1: give_item(id, "weapon_m4a1")
				case 2: give_item(id, "weapon_awp")
			}
		}
		case 1:
		{
			// Health
			client_print(id, print_chat, "You receive +100HP")
			client_print(id, print_chat, "Made by Sneaky.amxx QQ @ 1282743988")
			set_user_health(id, get_user_health(id) + 100)
		}
		case 2:
		{
			// Invisible
			client_print(id, print_chat, "You receive 'Invisibility'")
			client_print(id, print_chat, "Made by Sneaky.amxx QQ @ 1282743988")
			set_entity_visibility(id, 0)
		}
		case 3:
		{
			// Increase speed
			g_Has_Speed[id] = 1
			
			client_print(id, print_chat, "You receive 'Speed Up'")
			client_print(id, print_chat, "Made by Sneaky.amxx QQ @ 1282743988")
			set_pev(id, pev_maxspeed, 350.0)
		}
		case 4:
		{
			// Double Jump
			g_Has_DoubleJump[id] = 1	
			
			client_print(id, print_chat, "You receive 'Double Jump'")
			client_print(id, print_chat, "Made by Sneaky.amxx QQ @ 1282743988")
		}
		case 5:
		{
			// Double Damage
			g_Has_DoubleDamage[id] = 1
			
			client_print(id, print_chat, "You receive 'Double Damage'")
			client_print(id, print_chat, "Made by Sneaky.amxx QQ @ 1282743988")
		}
	}
}

public KOROSU(id)
{
	id -= 333
	
	if(!is_user_alive(id))
		return
	
	user_kill(id)
	static Float:Origin[3]; 
	pev(Long, pev_angles, Origin); Origin[2] -= 36.0
	
	fuck_ent(id, Origin, 5000.0)
}

public KOROSU2(Ent)
{
	if(!pev_valid(Ent)) return
	
	emit_sound(Long, CHAN_ITEM, Sound[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)	
}

stock fuck_ent(ent, Float:VicOrigin[3], Float:speed)
{
	if(!pev_valid(ent))
		return
	
	static Float:fl_Velocity[3], Float:EntOrigin[3], Float:distance_f, Float:fl_Time
	
	pev(ent, pev_origin, EntOrigin)
	
	distance_f = get_distance_f(EntOrigin, VicOrigin)
	fl_Time = distance_f / speed
		
	fl_Velocity[0] = (EntOrigin[0]- VicOrigin[0]) / fl_Time
	fl_Velocity[1] = (EntOrigin[1]- VicOrigin[1]) / fl_Time
	fl_Velocity[2] = (EntOrigin[2]- VicOrigin[2]) / fl_Time

	fl_Velocity[2] += 1000.0
	
	set_pev(ent, pev_velocity, fl_Velocity)
}

stock fuck_ent2(ent, Float:VicOrigin[3], Float:speed)
{
	if(!pev_valid(ent))
		return
	
	static Float:fl_Velocity[3], Float:EntOrigin[3], Float:distance_f, Float:fl_Time
	
	pev(ent, pev_origin, EntOrigin)

	distance_f = get_distance_f(EntOrigin, VicOrigin)
	if(!distance_f) 
	{
		fl_Velocity[0] = 2000.0
		fl_Velocity[1] = 2000.0
		fl_Velocity[2] = 100.0
		set_pev(ent, pev_velocity, fl_Velocity)
		return
	}
	
	fl_Time = distance_f / speed
	
		
	fl_Velocity[0] = (EntOrigin[0] - VicOrigin[0]) / fl_Time
	fl_Velocity[1] = (EntOrigin[1] - VicOrigin[1]) / fl_Time
	fl_Velocity[2] = (EntOrigin[2] - VicOrigin[2]) / fl_Time

	fl_Velocity[2] = 0.0
	
	set_pev(ent, pev_velocity, fl_Velocity)
}

public menu_main(id)
{
	// check is admin

	// remove task
	if (task_exists(id+TASK_SHOW_SPAWNS)) remove_task(id+TASK_SHOW_SPAWNS)
	if (task_exists(id+TASK_SHOW_BOXS)) remove_task(id+TASK_SHOW_BOXS)
	
	
	// set task show point
	if (task_exists(id+TASK_SHOW_SPAWNS)) remove_task(id+TASK_SHOW_SPAWNS)
	set_task(1.0, "task_show_spawns", id+TASK_SHOW_SPAWNS, _, _, "b")

	spawn_main(id)
}

public task_show_spawns(taskid)
{
	new id = ID_SHOW_SPAWNS
	spawn_show(id)
	
}

//######################################################################
// SPAWNS POINTS
//######################################################################
// ===================== SPAWN MAIN MENU =====================
public spawn_main(id)
{
	// remove spawns choose
	g_spawn_edit = -1
	
	// create menu
	new title[64], item_name[5][64]
	format(title, charsmax(title), "[Points] Current Point: %i/%i", g_total_spawns, MAX_SPAWNS)
	format(item_name[0], 63, "ADD")
	format(item_name[1], 63, "EDIT")
	format(item_name[2], 63, "SAVE")
	format(item_name[3], 63, "LOAD")
	format(item_name[4], 63, "DEL")

	new mHandleID = menu_create(title, "spawn_main_handler")
	menu_additem(mHandleID, item_name[0], "add", 0)
	menu_additem(mHandleID, item_name[1], "edit", 0)
	menu_additem(mHandleID, item_name[2], "save", 0)
	menu_additem(mHandleID, item_name[3], "load", 0)
	menu_additem(mHandleID, item_name[4], "del", 0)
	menu_display(id, mHandleID, 0)
}
public spawn_main_handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		// destroy menu
		menu_destroy(menu)
		
		if (task_exists(id+TASK_SHOW_SPAWNS)) remove_task(id+TASK_SHOW_SPAWNS)
		if (task_exists(id+TASK_SHOW_BOXS)) remove_task(id+TASK_SHOW_BOXS)
		
		return;
	}
	
	new itemid[32], itemname[32], access
	menu_item_getinfo(menu, item, access, itemid, charsmax(itemid), itemname, charsmax(itemname), access)
	menu_destroy(menu)
	
	if (equal(itemid, "add"))
	{
		spawn_create(id)
		return;
	}
	else if (equal(itemid, "edit"))
	{
		// set first value for g_spawn_edit
		g_spawn_edit = 0
		spawn_edit(id)
		return;
	}
	else if (equal(itemid, "save")) spawn_save()
	else if (equal(itemid, "load")) spawn_load()
	else if (equal(itemid, "del")) spawn_del(1)
	
	// show main menu
	spawn_main(id)
}

// ===================== spawn create =====================
public spawn_create(id)
{
	// remove spawns choose
	g_spawn_edit = -1
	
	// create menu
	new title[64], item_name[3][64]
	format(title, charsmax(title), "[Points] Current Point: %i/%i", g_total_spawns, MAX_SPAWNS)
	format(item_name[0], 63, "ADD A POINT")
	
	format(item_name[2], 63, "DEL A POINT")

	new mHandleID = menu_create(title, "spawn_create_handler")
	menu_additem(mHandleID, item_name[0], "add", 0)
	
	menu_additem(mHandleID, item_name[2], "del", 0)
	menu_display(id, mHandleID, 0)
}
public spawn_create_handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		// destroy menu
		menu_destroy(menu)
		// show menu main
		spawn_main(id)
		return;
	}
	
	new itemid[32], itemname[32], access
	menu_item_getinfo(menu, item, access, itemid, charsmax(itemid), itemname, charsmax(itemname), access)
	menu_destroy(menu)

	if (equali(itemid, "add")) spawn_create_add(id)
	else if (equali(itemid, "del")) spawn_del()

	// return menu create spawns
	spawn_create(id)
	
	return;
}
spawn_create_add(id)
{
	// check max points
	if (g_total_spawns>=MAX_SPAWNS)
	{
		new message[128]
		format(message, charsmax(message), ">x04[NST Points] >x01 Max Spawn %i", MAX_SPAWNS)
		color_saytext(id, message)
		return;
	}
	
	// add current points
	new Float:originF[3], origin[3]
	pev(id, pev_origin, originF)
	origin[0] = floatround(originF[0])
	origin[1] = floatround(originF[1])
	origin[2] = floatround(originF[2])
	
	if (!is_point(origin) || !spawn_check_dist(originF))
	{
		new message[128]
		format(message, charsmax(message), ">x04[NST Points] >x01 Too Closer to each other")
		color_saytext(id, message)
		return;
	}
	
	g_spawns[g_total_spawns][0] = origin[0]
	g_spawns[g_total_spawns][1] = origin[1]
	g_spawns[g_total_spawns][2] = origin[2]
	g_total_spawns ++
}

// ===================== spawn edit =====================
public spawn_edit(id)
{
	// check total
	if (!g_total_spawns)
	{
		new message[128]
		format(message, charsmax(message), ">x04[NST Points] >x01 Not Value")
		color_saytext(id, message)
		spawn_main(id)
		return;
	}
	
	// create menu
	new title[64], item_name[4][64]
	format(title, charsmax(title), "[NST Points] %L", LANG_PLAYER, "MENU_SPAWNS_EDIT_TITLE")
	format(item_name[0], 63, "%L", LANG_PLAYER, "MENU_SPAWNS_EDIT_ITEM_BACK")
	format(item_name[1], 63, "%L", LANG_PLAYER, "MENU_SPAWNS_EDIT_ITEM_NEXT")
	format(item_name[2], 63, "%L", LANG_PLAYER, "MENU_SPAWNS_EDIT_ITEM_EDIT")
	format(item_name[3], 63, "%L", LANG_PLAYER, "MENU_SPAWNS_EDIT_ITEM_DEL")

	new mHandleID = menu_create(title, "spawn_edit_handler")
	menu_additem(mHandleID, item_name[0], "back", 0)
	menu_additem(mHandleID, item_name[1], "next", 0)
	menu_additem(mHandleID, item_name[2], "edit", 0)
	menu_additem(mHandleID, item_name[3], "del", 0)
	menu_display(id, mHandleID, 0)
}
public spawn_edit_handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		// destroy menu
		menu_destroy(menu)
		// show menu main
		//spawn_main(id)
		return;
	}
	
	new itemid[32], itemname[32], access
	menu_item_getinfo(menu, item, access, itemid, charsmax(itemid), itemname, charsmax(itemname), access)
	
	if (equal(itemid, "back")) spawn_edit_back()
	else if (equal(itemid, "next")) spawn_edit_next()
	else if (equal(itemid, "edit")) spawn_edit_edit(id, g_spawn_edit)
	else if (equal(itemid, "del")) spawn_edit_del(g_spawn_edit)
	
	menu_destroy(menu)
	
	// return menu
	spawn_edit(id)
}
spawn_edit_back()
{
	if (g_spawn_edit<=0) g_spawn_edit = g_total_spawns-1
	else g_spawn_edit --
}
spawn_edit_next()
{
	if (g_spawn_edit<0 || g_spawn_edit>=g_total_spawns-1) g_spawn_edit = 0
	else g_spawn_edit ++
}
spawn_edit_edit(id, point)
{
	// check value
	if (point<0 || point>=g_total_spawns) return;

	// get points
	new Float:originF[3], origin[3]
	pev(id, pev_origin, originF)
	origin[0] = floatround(originF[0])
	origin[1] = floatround(originF[1])
	origin[2] = floatround(originF[2])
	
	// check point
	if (!is_point(origin) || !spawn_check_dist(originF, point))
	{
		new message[128]
		format(message, charsmax(message), ">x04[NST Points] >x01 Too closer to each other")
		color_saytext(0, message)
		return;
	}
	
	// update
	g_spawns[point][0] = origin[0]
	g_spawns[point][1] = origin[1]
	g_spawns[point][2] = origin[2]
}
spawn_edit_del(spawn)
{
	// check value
	if (spawn<0 || spawn>=g_total_spawns) return;
	
	// del spawn point
	new spawn_r[3]
	g_spawns[spawn] = spawn_r
	
	// create g_spawns_r
	reset_spawn(1)
	new total_s, point[3]
	for (new i=0; i<g_total_spawns; i++)
	{
		point[0] = g_spawns[i][0]
		point[1] = g_spawns[i][1]
		point[2] = g_spawns[i][2]
		if (is_point(point))
		{
			g_spawns_r[total_s][0] = point[0]
			g_spawns_r[total_s][1] = point[1]
			g_spawns_r[total_s][2] = point[2]
			
			total_s ++
		}
	}
	
	// update g_spawns
	spawn_del(1)
	for (new s=0; s<total_s; s++)
	{
		g_spawns[s][0] = g_spawns_r[s][0]
		g_spawns[s][1] = g_spawns_r[s][1]
		g_spawns[s][2] = g_spawns_r[s][2]
	}
	g_total_spawns = total_s
	if (spawn) g_spawn_edit = spawn-1
}

// ===================== spawn save =====================
spawn_save()
{
	// check total
	if (!g_total_spawns)
	{
		new message[128]
		format(message, charsmax(message), ">x04[NST Points] >x01 Not value")
		color_saytext(0, message)
		return;
	}

	// get url file
	new cfgdir[32], mapname[32], urlfile[64]
	get_configsdir(cfgdir, charsmax(cfgdir))
	get_mapname(mapname, charsmax(mapname))
	formatex(urlfile, charsmax(urlfile), SPAWNS_URL, cfgdir, mapname)

	// save file
	if (file_exists(urlfile)) delete_file(urlfile)
	new lineset[128]
	for (new i=0; i<g_total_spawns; i++)
	{
		if (!g_spawns[i][0] && !g_spawns[i][1] && !g_spawns[i][2]) break;
		
		format(lineset, charsmax(lineset), "%i %i %i", g_spawns[i][0], g_spawns[i][1], g_spawns[i][2])
		write_file(urlfile, lineset, i)
	}
	
	// show notice
	new message[128]
	format(message, charsmax(message), ">x04[NST Points] >x01 Save Completed")
	color_saytext(0, message)
}

// ===================== spawn load =====================
spawn_load()
{
	// Check for spawns points of the current map
	new cfgdir[32], mapname[32], filepath[100], linedata[64], point[3]
	get_configsdir(cfgdir, charsmax(cfgdir))
	get_mapname(mapname, charsmax(mapname))
	formatex(filepath, charsmax(filepath), SPAWNS_URL, cfgdir, mapname)
	
	// check file exit
	if (!file_exists(filepath))
	{
		new message[128]
		format(message, charsmax(message), ">x04[NST Points] >x01 File not found %s", filepath)
		color_saytext(0, message)
		return;
	}
	
	// first reset value
	reset_spawn()
	
	// Load spawns points
	new file = fopen(filepath,"rt"), row[4][6]
	while (file && !feof(file))
	{
		fgets(file, linedata, charsmax(linedata))
		
		// invalid spawn
		if(!linedata[0] || str_count(linedata,' ') < 2) continue;
		
		// get spawn point data
		parse(linedata,row[0],5,row[1],5,row[2],5,row[3],5)
		
		// set spawnst
		point[0] = str_to_num(row[0])
		point[1] = str_to_num(row[1])
		point[2] = str_to_num(row[2])
		if (is_point(point))
		{
			g_spawns[g_total_spawns][0] = point[0]
			g_spawns[g_total_spawns][1] = point[1]
			g_spawns[g_total_spawns][2] = point[2]
	
			// increase spawn count
			g_total_spawns ++
			if (g_total_spawns>=MAX_SPAWNS) break;
		}
	}
	if (file) fclose(file)
	
	// notice
	if (g_total_spawns)
	{
		new message[128]
		format(message, charsmax(message), ">x04[NST Points] >x01 Load Completed: %i", g_total_spawns)
		color_saytext(0, message)
	}
}

// ===================== spawn del all =====================
spawn_del(all=0)
{
	// check total
	if (!g_total_spawns)
	{
		new message[128]
		format(message, charsmax(message), ">x04[NST Points] >x01% Not value")
		color_saytext(0, message)
		return;
	}
	
	// del all
	if (all)
	{
		reset_spawn()
	}
	// del newest points
	else
	{
		static reset[3]
		g_total_spawns --
		g_spawns[g_total_spawns] = reset
	}
}

// ===================== other function =====================
spawn_show(id)
{
	if (!g_total_spawns) return;
	
	new color[3], start[3], end[3]
	for (new i=0; i<g_total_spawns; i++)
	{
		if (i==g_spawn_edit) color = color_point_edit
		else color = color_spawn_bot
		start[0] = g_spawns[i][0]
		start[1] = g_spawns[i][1]
		start[2] = g_spawns[i][2]
		if (!is_point(start)) return;
		end = start
		start[2] -= 36
		end[2] += 36

		create_line_point(id, start, end, color)
	}
}
spawn_check_dist(Float:origin[3], point=-1)
{
	new Float:originE[3], Float:origin1[3], Float:origin2[3]
	
	for (new i=0; i<g_total_spawns; i++)
	{
		if (i==point) continue;
		
		originE[0] = float(g_spawns[i][0])
		originE[1] = float(g_spawns[i][1])
		originE[2] = float(g_spawns[i][2])
		
		// xoy
		origin1 = origin
		origin2 = originE
		origin1[2] = origin2[2] = 0.0
		if (vector_distance(origin1, origin2)<=2*16.0)
		{
			// oz
			origin1 = origin
			origin2 = originE
			origin1[0] = origin2[0] = origin1[1] = origin2[1] = 0.0
			if (vector_distance(origin1, origin2)<=100.0) return 0;
		}
	}

	return 1;
}




//######################################################################
// FUNCTION MAIN
//######################################################################

reset_spawn(t=0)
{
	for (new s=0; s<MAX_SPAWNS; s++)
	{
		for (new i=0; i<3; i++)
		{
			if (t) g_spawns_r[s][i] = 0
			else g_spawns[s][i] = 0
		}
	}
	if (!t) g_total_spawns = 0
}


is_point(point[3])
{
	if (!point[0] && !point[1] && !point[2]) return 0
	return 1
}
create_line_point(id, const start[3], const end[3], const color[3])
{
	if (!is_user_connected(id)) return;
	
	message_begin(MSG_ONE, SVC_TEMPENTITY, {0,0,0}, id)
	write_byte(TE_BEAMPOINTS)	// temp entity event
	write_coord(start[0])		// startposition: x
	write_coord(start[1])		// startposition: y
	write_coord(start[2])		// startposition: z
	write_coord(end[0])		// endposition: x
	write_coord(end[1])		// endposition: y
	write_coord(end[2])		// endposition: z
	write_short(cache_spr_line)	// sprite index
	write_byte(0)			// start frame
	write_byte(0)			// framerate
	write_byte(10)			// life in 0.1's
	write_byte(15)			// line width in 0.1's
	write_byte(0)			// noise amplitude in 0.01's
	write_byte(color[0])		// color: red
	write_byte(color[1])		// color: green
	write_byte(color[2])		// color: blue
	write_byte(200)			// brightness
	write_byte(0)			// scroll speed in 0.1's
	message_end()
}
color_saytext(player, const message[], any:...)
{
	new text[256]
	format(text, charsmax(text), "%s",message)
	format(text, charsmax(text), "%s",check_text(text))
	
	new dest
	if (player) dest = MSG_ONE
	else dest = MSG_ALL
	
	message_begin(dest, get_user_msgid("SayText"), {0,0,0}, player)
	write_byte(1)
	write_string(text)
	message_end()
}
check_text(text1[])
{
	new text[256]
	format(text, charsmax(text), "%s", text1)
	
	replace_all(text, charsmax(text), ">x04", "^x04")
	replace_all(text, charsmax(text), ">x03", "^x03")
	replace_all(text, charsmax(text), ">x01", "^x01")

	return text
}
str_count(const str[], searchchar)
{
	new count, i, len = strlen(str)
	
	for (i = 0; i <= len; i++)
	{
		if(str[i] == searchchar)
			count++
	}
	
	return count;
}

public Aim_To(iEnt, Float:vTargetOrigin[3], Float:flSpeed, Style)
{
	if(!pev_valid(iEnt))	
		return
		
	if(!Style)
	{
		static Float:Vec[3], Float:Angles[3]
		pev(iEnt, pev_origin, Vec)
		
		Vec[0] = vTargetOrigin[0] - Vec[0]
		Vec[1] = vTargetOrigin[1] - Vec[1]
		Vec[2] = vTargetOrigin[2] - Vec[2]
		engfunc(EngFunc_VecToAngles, Vec, Angles)
		if(!is_user_alive(iEnt)) Angles[0] = Angles[2] = 0.0 
		
		set_pev(iEnt, pev_v_angle, Angles)
		set_pev(iEnt, pev_angles, Angles)
		set_pev(iEnt, pev_fixangle, 1)
	} else {
		new Float:f1, Float:f2, Float:fAngles, Float:vOrigin[3], Float:vAim[3], Float:vAngles[3];
		pev(iEnt, pev_origin, vOrigin);
		xs_vec_sub(vTargetOrigin, vOrigin, vOrigin);
		xs_vec_normalize(vOrigin, vAim);
		vector_to_angle(vAim, vAim);
		
		if (vAim[1] > 180.0) vAim[1] -= 360.0;
		if (vAim[1] < -180.0) vAim[1] += 360.0;
		
		fAngles = vAim[1];
		pev(iEnt, pev_angles, vAngles);
		
		if (vAngles[1] > fAngles)
		{
			f1 = vAngles[1] - fAngles;
			f2 = 360.0 - vAngles[1] + fAngles;
			if (f1 < f2)
			{
				vAngles[1] -= flSpeed;
				vAngles[1] = floatmax(vAngles[1], fAngles);
			}
			else
			{
				vAngles[1] += flSpeed;
				if (vAngles[1] > 180.0) vAngles[1] -= 360.0;
			}
		}
		else
		{
			f1 = fAngles - vAngles[1];
			f2 = 360.0 - fAngles + vAngles[1];
			if (f1 < f2)
			{
				vAngles[1] += flSpeed;
				vAngles[1] = floatmin(vAngles[1], fAngles);
			}
			else
			{
				vAngles[1] -= flSpeed;
				if (vAngles[1] < -180.0) vAngles[1] += 360.0;
			}		
		}
	
		set_pev(iEnt, pev_v_angle, vAngles)
		set_pev(iEnt, pev_angles, vAngles)
	}
}

public FindClosetEnemy(ent, can_see)
{
	new Float:maxdistance = 4980.0
	new indexid = 0	
	new Float:current_dis = maxdistance

	static g_MaxPlayers; if(!g_MaxPlayers) g_MaxPlayers = get_maxplayers()
	
	for(new i = 1 ;i <= g_MaxPlayers; i++)
	{
		if(can_see)
		{
			if(is_user_alive(i) && can_see_fm(ent, i) && entity_range(ent, i) < current_dis)
			{
				current_dis = entity_range(ent, i)
				indexid = i
			}
		} else {
			if(is_user_alive(i) && entity_range(ent, i) < current_dis)
			{
				current_dis = entity_range(ent, i)
				indexid = i
			}			
		}
	}	
	
	return indexid
}

public bool:can_see_fm(entindex1, entindex2)
{
	if (!entindex1 || !entindex2)
		return false

	if (pev_valid(entindex1) && pev_valid(entindex1))
	{
		new flags = pev(entindex1, pev_flags)
		if (flags & EF_NODRAW || flags & FL_NOTARGET)
		{
			return false
		}

		new Float:lookerOrig[3]
		new Float:targetBaseOrig[3]
		new Float:targetOrig[3]
		new Float:temp[3]

		pev(entindex1, pev_origin, lookerOrig)
		pev(entindex1, pev_view_ofs, temp)
		lookerOrig[0] += temp[0]
		lookerOrig[1] += temp[1]
		lookerOrig[2] += temp[2]

		pev(entindex2, pev_origin, targetBaseOrig)
		pev(entindex2, pev_view_ofs, temp)
		targetOrig[0] = targetBaseOrig [0] + temp[0]
		targetOrig[1] = targetBaseOrig [1] + temp[1]
		targetOrig[2] = targetBaseOrig [2] + temp[2]

		engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0) //  checks the had of seen player
		if (get_tr2(0, TraceResult:TR_InOpen) && get_tr2(0, TraceResult:TR_InWater))
		{
			return false
		} 
		else 
		{
			new Float:flFraction
			get_tr2(0, TraceResult:TR_flFraction, flFraction)
			if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2))
			{
				return true
			}
			else
			{
				targetOrig[0] = targetBaseOrig [0]
				targetOrig[1] = targetBaseOrig [1]
				targetOrig[2] = targetBaseOrig [2]
				engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0) //  checks the body of seen player
				get_tr2(0, TraceResult:TR_flFraction, flFraction)
				if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2))
				{
					return true
				}
				else
				{
					targetOrig[0] = targetBaseOrig [0]
					targetOrig[1] = targetBaseOrig [1]
					targetOrig[2] = targetBaseOrig [2] - 17.0
					engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0) //  checks the legs of seen player
					get_tr2(0, TraceResult:TR_flFraction, flFraction)
					if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2))
					{
						return true
					}
				}
			}
		}
	}
	return false
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
