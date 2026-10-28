/*
===========================================================================
Copyright (C) 1999-2005 Id Software, Inc.

This file is part of Quake III Arena source code.

Quake III Arena source code is free software; you can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation; either version 2 of the License,
or (at your option) any later version.

Quake III Arena source code is distributed in the hope that it will be
useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Quake III Arena source code; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
===========================================================================
*/
//
// bg_portal.c -- portal ends, read from the map's entity string and checked
// alike by both games

#include "../qcommon/q_shared.h"
#include "bg_public.h"

/*QUAKED info_portal_end (0 .5 1) (-8 -8 -8) (8 8 8)
One end of a portal: a rectangle lying flat on a surface of solid world, seen
and entered from its front. Its opening is filled by a plug, a brush with the
textures/quortal/plug shader on every face, flush with the surface.

"origin"		the centre of the opening, on the surface
"angles"		pitch yaw roll, as misc_model reads them: the end faces forward, and its height runs up
"angle"			yaw alone, in place of "angles"
"width"			the opening's width
"height"		the opening's height
"targetname"	the end's name
"target"		the name of the end it pairs with, which must target this one
"shader"		what the end shows past the nesting limit, black without one
*/

// the keys of an entity that a portal end is read from
typedef struct {
	char	classname[MAX_QPATH];
	char	origin[MAX_QPATH];
	char	angles[MAX_QPATH];
	char	angle[MAX_QPATH];
	char	width[MAX_QPATH];
	char	height[MAX_QPATH];
	char	targetname[MAX_QPATH];
	char	target[MAX_QPATH];
	char	shader[MAX_QPATH];
} portalEndKeys_t;

#define	PKOFS(x) ((size_t)&(((portalEndKeys_t *)0)->x))

static const struct {
	const char	*name;
	size_t		ofs;
} portalEndKeyFields[] = {
	{ "classname", PKOFS(classname) },
	{ "origin", PKOFS(origin) },
	{ "angles", PKOFS(angles) },
	{ "angle", PKOFS(angle) },
	{ "width", PKOFS(width) },
	{ "height", PKOFS(height) },
	{ "targetname", PKOFS(targetname) },
	{ "target", PKOFS(target) },
	{ "shader", PKOFS(shader) },
	{ NULL }
};

/*
================
BG_ParseNumbers

Reads count numbers, separated by spaces, from s into out, and returns qfalse
unless s holds that many numbers and nothing else
================
*/
static qboolean BG_ParseNumbers( const char *s, float *out, int count ) {
	char	buffer[MAX_QPATH];
	char	*p;
	char	*token;
	int		i;

	Q_strncpyz( buffer, s, sizeof( buffer ) );
	p = buffer;

	for ( i = 0 ; i < count ; i++ ) {
		token = COM_Parse( &p );
		if ( !Q_isanumber( token ) ) {
			return qfalse;
		}
		out[i] = atof( token );
	}

	return !COM_Parse( &p )[0];
}

/*
================
BG_ReadPortalEnd
================
*/
static void BG_ReadPortalEnd( const portalEndKeys_t *keys, portalEnd_t *end ) {
	vec3_t	angles;

	memset( end, 0, sizeof( *end ) );
	end->partner = -1;

	Q_strncpyz( end->targetname, keys->targetname, sizeof( end->targetname ) );
	Q_strncpyz( end->target, keys->target, sizeof( end->target ) );
	Q_strncpyz( end->shader, keys->shader, sizeof( end->shader ) );

	BG_ParseNumbers( keys->origin, end->origin, 3 );

	// the frame's keys are read in turn, until one can't be
	VectorClear( angles );
	if ( !BG_ParseNumbers( keys->width, &end->width, 1 ) || end->width <= 0 ) {
		end->rule = PR_NO_WIDTH;
	} else if ( !BG_ParseNumbers( keys->height, &end->height, 1 ) || end->height <= 0 ) {
		end->rule = PR_NO_HEIGHT;
	} else if ( keys->angles[0] && keys->angle[0] ) {
		end->rule = PR_ANGLE_AND_ANGLES;
	} else if ( keys->angles[0] && !BG_ParseNumbers( keys->angles, angles, 3 ) ) {
		end->rule = PR_BAD_ANGLES;
	} else if ( keys->angle[0] && !BG_ParseNumbers( keys->angle, &angles[YAW], 1 ) ) {
		end->rule = PR_BAD_ANGLES;
	}
	AnglesToAxis( angles, end->axis );

	// an end with no usable frame is skipped
	if ( end->rule != PR_NONE ) {
		end->state = PE_SKIPPED;
	}
}

/*
================
BG_ReadPortalEnds

Reads the map's info_portal_ends into ends, no more than maxEnds of them, and
returns how many the map has. The entity string's tokens are all read, so
that the game can read the string again from its start
================
*/
static int BG_ReadPortalEnds( qboolean (*getToken)( char *buffer, int bufferSize ), portalEnd_t *ends, int maxEnds ) {
	char			key[MAX_TOKEN_CHARS];
	char			value[MAX_TOKEN_CHARS];
	portalEndKeys_t	keys;
	int				numFound;
	int				i;

	memset( &keys, 0, sizeof( keys ) );
	numFound = 0;

	while ( getToken( key, sizeof( key ) ) ) {
		if ( !strcmp( key, "{" ) ) {
			memset( &keys, 0, sizeof( keys ) );
			continue;
		}

		if ( !strcmp( key, "}" ) ) {
			if ( !Q_stricmp( keys.classname, "info_portal_end" ) ) {
				if ( numFound < maxEnds ) {
					BG_ReadPortalEnd( &keys, &ends[numFound] );
				}
				numFound++;
			}
			continue;
		}

		if ( !getToken( value, sizeof( value ) ) ) {
			break;
		}

		for ( i = 0 ; portalEndKeyFields[i].name ; i++ ) {
			if ( !Q_stricmp( key, portalEndKeyFields[i].name ) ) {
				Q_strncpyz( (char *)&keys + portalEndKeyFields[i].ofs, value, MAX_QPATH );
				break;
			}
		}
	}

	return numFound;
}

/*
================
BG_FindPortalEnd

Returns the one end named name, -1 if no end is, or -2 if more than one is
================
*/
static int BG_FindPortalEnd( const portalEnd_t *ends, int numEnds, const char *name ) {
	int		found;
	int		i;

	found = -1;
	for ( i = 0 ; i < numEnds ; i++ ) {
		if ( Q_stricmp( ends[i].targetname, name ) ) {
			continue;
		}
		if ( found != -1 ) {
			return -2;
		}
		found = i;
	}

	return found;
}

/*
================
BG_PairPortalEnd

Returns the end that ends[endNum] pairs with, or -1 and the rule it broke.
Ends pair when each targets the other, by a name no other end has
================
*/
static int BG_PairPortalEnd( const portalEnd_t *ends, int numEnds, int endNum, portalRule_t *rule ) {
	const portalEnd_t	*end;
	int					partner;

	end = &ends[endNum];

	if ( !end->targetname[0] ) {
		*rule = PR_NO_TARGETNAME;
		return -1;
	}
	if ( BG_FindPortalEnd( ends, numEnds, end->targetname ) == -2 ) {
		*rule = PR_SHARED_TARGETNAME;
		return -1;
	}
	if ( !end->target[0] ) {
		*rule = PR_NO_TARGET;
		return -1;
	}
	if ( !Q_stricmp( end->target, end->targetname ) ) {
		*rule = PR_OWN_PARTNER;
		return -1;
	}

	partner = BG_FindPortalEnd( ends, numEnds, end->target );
	if ( partner == -1 ) {
		*rule = PR_NO_SUCH_TARGET;
		return -1;
	}
	if ( partner == -2 ) {
		*rule = PR_SHARED_TARGET;
		return -1;
	}
	if ( Q_stricmp( ends[partner].target, end->targetname ) ) {
		*rule = PR_NOT_MUTUAL;
		return -1;
	}

	return partner;
}

/*
================
BG_CheckPortalEnds

Pairs the ends and checks them, giving each its state, and the rule it broke
if it broke one. A portal is open only when both its ends broke none: an end
that broke one seals its partner, and an end that was skipped as it was read
still pairs, to seal its partner
================
*/
static void BG_CheckPortalEnds( portalEnd_t *ends, int numEnds ) {
	portalEnd_t		*end;
	portalEnd_t		*partner;
	portalRule_t	rule;
	int				i;

	for ( i = 0 ; i < numEnds ; i++ ) {
		end = &ends[i];
		end->partner = BG_PairPortalEnd( ends, numEnds, i, &rule );
		if ( end->partner == -1 && end->rule == PR_NONE ) {
			end->rule = rule;
		}
	}

	// a portal whose ends differ in size breaks the rule once, at the end
	// whose name sorts first
	for ( i = 0 ; i < numEnds ; i++ ) {
		end = &ends[i];
		if ( end->partner == -1 ) {
			continue;
		}

		partner = &ends[end->partner];
		if ( end->rule != PR_NONE || partner->rule != PR_NONE ) {
			continue;
		}
		if ( Q_stricmp( end->targetname, partner->targetname ) > 0 ) {
			continue;
		}
		if ( end->width != partner->width || end->height != partner->height ) {
			end->rule = PR_SIZE_MISMATCH;
		}
	}

	for ( i = 0 ; i < numEnds ; i++ ) {
		end = &ends[i];
		if ( end->state == PE_SKIPPED ) {
			continue;
		}
		if ( end->rule != PR_NONE ) {
			end->state = PE_SEALED;
			continue;
		}

		partner = &ends[end->partner];
		if ( partner->rule != PR_NONE ) {
			end->state = PE_SEALED;
			continue;
		}

		end->state = PE_OPEN;
		VectorMA( partner->origin, PORTAL_VIS_DISTANCE, partner->axis[0], end->visOrigin );
	}
}

/*
================
BG_PortalEndRule

Says which rule end broke, or returns NULL if it broke none
================
*/
static const char *BG_PortalEndRule( const portalEnd_t *end ) {
	switch ( end->rule ) {
	case PR_NO_WIDTH:
		return "has no width";
	case PR_NO_HEIGHT:
		return "has no height";
	case PR_ANGLE_AND_ANGLES:
		return "has both angle and angles";
	case PR_BAD_ANGLES:
		return "has unreadable angles";
	case PR_NO_TARGETNAME:
		return "doesn't pair, as it has no targetname";
	case PR_SHARED_TARGETNAME:
		return "doesn't pair, as another end has its targetname";
	case PR_NO_TARGET:
		return "doesn't pair, as it has no target";
	case PR_NO_SUCH_TARGET:
		return va( "doesn't pair, as no end is named \"%s\"", end->target );
	case PR_SHARED_TARGET:
		return va( "doesn't pair, as more than one end is named \"%s\"", end->target );
	case PR_NOT_MUTUAL:
		return va( "doesn't pair, as \"%s\" doesn't target it", end->target );
	case PR_OWN_PARTNER:
		return "targets itself";
	case PR_SIZE_MISMATCH:
		return va( "isn't the size of its partner \"%s\"", end->target );
	default:
		return NULL;
	}
}

/*
================
BG_PortalEndWarning

Returns the warning about the rule end broke, naming it and its position, or
NULL if it broke none. An end sealed by its partner breaks none
================
*/
static const char *BG_PortalEndWarning( const portalEnd_t *end ) {
	static char	warning[MAX_STRING_CHARS];
	const char	*rule;

	rule = BG_PortalEndRule( end );
	if ( !rule ) {
		return NULL;
	}

	Com_sprintf( warning, sizeof( warning ), S_COLOR_YELLOW "WARNING: portal end \"%s\" at (%i %i %i) %s\n",
		end->targetname, (int)end->origin[0], (int)end->origin[1], (int)end->origin[2], rule );

	return warning;
}

/*
================
BG_LoadPortalEnds

Reads the map's portal ends into ends, and checks them, giving each its
verdict. Returns how many were read.

getToken returns the map's entity string token by token, as
trap_GetEntityToken does. warn, unless it's NULL, is given a warning for each
rule an end breaks
================
*/
int BG_LoadPortalEnds( qboolean (*getToken)( char *buffer, int bufferSize ),
		void (*warn)( const char *warning ), portalEnd_t *ends, int maxEnds ) {
	const char	*warning;
	int			numFound;
	int			numEnds;
	int			i;

	numFound = BG_ReadPortalEnds( getToken, ends, maxEnds );
	numEnds = MIN( numFound, maxEnds );
	BG_CheckPortalEnds( ends, numEnds );

	if ( !warn ) {
		return numEnds;
	}

	if ( numFound > numEnds ) {
		warn( va( S_COLOR_YELLOW "WARNING: the map has %i portal ends, and only the first %i are read\n",
			numFound, numEnds ) );
	}

	for ( i = 0 ; i < numEnds ; i++ ) {
		warning = BG_PortalEndWarning( &ends[i] );
		if ( warning ) {
			warn( warning );
		}
	}

	return numEnds;
}
