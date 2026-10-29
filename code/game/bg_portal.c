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
	end->overlap = -1;

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

// a portal end's plug, and the world around it, are checked to within this
// distance of where its keys place them
#define	PORTAL_TOLERANCE		1

// and sampled at each edge, and this far apart between them
#define	PORTAL_SAMPLE_SPACING	16

/*
================
BG_PortalSampleCount

Returns how many points a span reaching half either side of its centre is
sampled at: both its ends, its centre, and every PORTAL_SAMPLE_SPACING units
out from its centre
================
*/
static int BG_PortalSampleCount( float half ) {
	int		steps;

	if ( half <= 0 ) {
		return 1;
	}

	// the steps out from the centre, the last of them to the span's end
	steps = (int)( half / PORTAL_SAMPLE_SPACING );
	if ( steps * PORTAL_SAMPLE_SPACING < half ) {
		steps++;
	}

	return 2 * steps + 1;
}

/*
================
BG_PortalSample

Returns the i'th of the count points a span reaching half either side of its
centre is sampled at, from one end to the other, as an offset from its centre
================
*/
static float BG_PortalSample( float half, int i, int count ) {
	if ( count == 1 ) {
		return 0;
	}
	if ( i == 0 ) {
		return -half;
	}
	if ( i == count - 1 ) {
		return half;
	}
	return ( i - count / 2 ) * PORTAL_SAMPLE_SPACING;
}

/*
================
BG_PortalEndLayerHolds

Samples the world across a rectangle parallel to end's opening, reaching
halfWidth and halfHeight either side of its centre, and depth behind its
surface, or in front of it when depth is negative. With edgesOnly, only the
rectangle's edges are sampled. Returns qtrue if the contents of every sample
hold all of need and none of forbid
================
*/
static qboolean BG_PortalEndLayerHolds( const portalEnd_t *end, int (*pointContents)( const vec3_t point ),
		float halfWidth, float halfHeight, float depth, qboolean edgesOnly, int need, int forbid ) {
	vec3_t	point;
	int		numAcross, numUp;
	int		contents;
	int		i, j;

	numAcross = BG_PortalSampleCount( halfWidth );
	numUp = BG_PortalSampleCount( halfHeight );

	for ( i = 0 ; i < numAcross ; i++ ) {
		for ( j = 0 ; j < numUp ; j++ ) {
			if ( edgesOnly && i > 0 && i < numAcross - 1 && j > 0 && j < numUp - 1 ) {
				continue;
			}

			VectorMA( end->origin, BG_PortalSample( halfWidth, i, numAcross ), end->axis[1], point );
			VectorMA( point, BG_PortalSample( halfHeight, j, numUp ), end->axis[2], point );
			VectorMA( point, -depth, end->axis[0], point );

			contents = pointContents( point );
			if ( ( contents & need ) != need || ( contents & forbid ) ) {
				return qfalse;
			}
		}
	}

	return qtrue;
}

/*
================
BG_CheckPortalEndWorld

Returns the first rule the world around end breaks, or PR_NONE. The world is
sampled at the opening's corners, along its edges, and across it every
PORTAL_SAMPLE_SPACING units out from its centre
================
*/
static portalRule_t BG_CheckPortalEndWorld( const portalEnd_t *end, int (*pointContents)( const vec3_t point ) ) {
	vec3_t	point;
	float	halfWidth, halfHeight, halfDepth;
	int		numDeep;
	int		i;

	// the samples in the opening fall short of its edges by the tolerance
	halfWidth = end->width / 2 - PORTAL_TOLERANCE;
	halfHeight = end->height / 2 - PORTAL_TOLERANCE;

	// the plug fills the opening, PORTAL_PLUG_DEPTH units deep, sampled at
	// its front and back as well as between. It isn't solid, and nothing
	// solid fills the opening with it. It's flush with the surface, so none
	// of it stands in front
	if ( !BG_PortalEndLayerHolds( end, pointContents, halfWidth, halfHeight,
			-PORTAL_TOLERANCE, qfalse, 0, CONTENTS_PLUG ) ) {
		return PR_UNFILLED;
	}

	halfDepth = PORTAL_PLUG_DEPTH / 2 - PORTAL_TOLERANCE;
	numDeep = BG_PortalSampleCount( halfDepth );
	for ( i = 0 ; i < numDeep ; i++ ) {
		if ( !BG_PortalEndLayerHolds( end, pointContents, halfWidth, halfHeight,
				PORTAL_PLUG_DEPTH / 2 + BG_PortalSample( halfDepth, i, numDeep ), qfalse,
				CONTENTS_PLUG, CONTENTS_SOLID ) ) {
			return PR_UNFILLED;
		}
	}

	// solid world lies behind the plug
	if ( !BG_PortalEndLayerHolds( end, pointContents, halfWidth, halfHeight,
			PORTAL_PLUG_DEPTH + PORTAL_TOLERANCE, qfalse, CONTENTS_SOLID, 0 ) ) {
		return PR_OPEN_BEHIND;
	}

	// and a solid rim surrounds the opening, just beyond its edges and just
	// behind its surface
	if ( !BG_PortalEndLayerHolds( end, pointContents, end->width / 2 + PORTAL_TOLERANCE,
			end->height / 2 + PORTAL_TOLERANCE, PORTAL_TOLERANCE, qtrue, CONTENTS_SOLID, 0 ) ) {
		return PR_NO_RIM;
	}

	// the space just in front of the end is clear of solid
	if ( !BG_PortalEndLayerHolds( end, pointContents, halfWidth, halfHeight,
			-PORTAL_TOLERANCE, qfalse, 0, CONTENTS_SOLID ) ) {
		return PR_BLOCKED_FRONT;
	}

	// and so is its partner's visibility point, in front of it
	VectorMA( end->origin, PORTAL_VIS_DISTANCE, end->axis[0], point );
	if ( pointContents( point ) & CONTENTS_SOLID ) {
		return PR_BLOCKED_VIS_POINT;
	}

	return PR_NONE;
}

/*
================
BG_PortalPlugsOverlap

Returns qtrue if the plugs of a and b, as their keys place them, overlap by
more than PORTAL_TOLERANCE. Each plug is a box, and two boxes are apart when
some axis separates them, as the shadows they cast on it don't overlap. Only
the axes of each box, and the cross products of an axis of one with an axis
of the other, need be tried
================
*/
static qboolean BG_PortalPlugsOverlap( const portalEnd_t *a, const portalEnd_t *b ) {
	vec3_t	axes[15];
	vec3_t	extentsA, extentsB;
	vec3_t	delta;
	float	reach;
	int		numAxes;
	int		i, j;

	// from the centre of a's box to b's, each half the plug's depth behind
	// its opening's
	VectorSubtract( b->origin, a->origin, delta );
	VectorMA( delta, -PORTAL_PLUG_DEPTH / 2, b->axis[0], delta );
	VectorMA( delta, PORTAL_PLUG_DEPTH / 2, a->axis[0], delta );

	// how far each box reaches from its centre along its own axes
	VectorSet( extentsA, PORTAL_PLUG_DEPTH / 2, a->width / 2, a->height / 2 );
	VectorSet( extentsB, PORTAL_PLUG_DEPTH / 2, b->width / 2, b->height / 2 );

	numAxes = 0;
	for ( i = 0 ; i < 3 ; i++ ) {
		VectorCopy( a->axis[i], axes[numAxes++] );
		VectorCopy( b->axis[i], axes[numAxes++] );
	}

	// the cross product of two parallel axes is no axis at all
	for ( i = 0 ; i < 3 ; i++ ) {
		for ( j = 0 ; j < 3 ; j++ ) {
			CrossProduct( a->axis[i], b->axis[j], axes[numAxes] );
			if ( VectorNormalize( axes[numAxes] ) > 0.001f ) {
				numAxes++;
			}
		}
	}

	// along each axis, the shadows overlap by how far the boxes reach
	// together, less how far apart their centres are
	for ( i = 0 ; i < numAxes ; i++ ) {
		reach = 0;
		for ( j = 0 ; j < 3 ; j++ ) {
			reach += extentsA[j] * fabs( DotProduct( a->axis[j], axes[i] ) );
			reach += extentsB[j] * fabs( DotProduct( b->axis[j], axes[i] ) );
		}

		if ( reach - fabs( DotProduct( delta, axes[i] ) ) <= PORTAL_TOLERANCE ) {
			return qfalse;
		}
	}

	return qtrue;
}

/*
================
BG_CheckPortalEnds

Pairs the ends and checks them, giving each its state, and the rule it broke
if it broke one. An end is checked against the world around it only once it
has broken no other rule. Both ends whose plugs overlap break that rule, so
that both their portals are sealed. A portal is open only when both its ends
broke none: an end that broke one seals its partner, and an end that was
skipped as it was read still pairs, to seal its partner
================
*/
static void BG_CheckPortalEnds( int (*pointContents)( const vec3_t point ), portalEnd_t *ends, int numEnds ) {
	portalEnd_t		*end;
	portalEnd_t		*partner;
	portalEnd_t		*other;
	portalRule_t	rule;
	int				i, j;

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

	// no two plugs overlap, whatever other rules their ends break
	for ( i = 0 ; i < numEnds ; i++ ) {
		end = &ends[i];
		if ( end->state == PE_SKIPPED ) {
			continue;
		}

		for ( j = i + 1 ; j < numEnds ; j++ ) {
			other = &ends[j];
			if ( other->state == PE_SKIPPED || !BG_PortalPlugsOverlap( end, other ) ) {
				continue;
			}

			if ( end->rule == PR_NONE ) {
				end->rule = PR_PLUG_OVERLAP;
				end->overlap = j;
			}
			if ( other->rule == PR_NONE ) {
				other->rule = PR_PLUG_OVERLAP;
				other->overlap = i;
			}
		}
	}

	for ( i = 0 ; i < numEnds ; i++ ) {
		end = &ends[i];
		if ( end->rule == PR_NONE ) {
			end->rule = BG_CheckPortalEndWorld( end, pointContents );
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

Says which rule ends[endNum] broke, or returns NULL if it broke none
================
*/
const char *BG_PortalEndRule( const portalEnd_t *ends, int endNum ) {
	const portalEnd_t	*end;

	end = &ends[endNum];

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
	case PR_PLUG_OVERLAP:
		return va( "overlaps the plug of \"%s\"", ends[end->overlap].targetname );
	case PR_UNFILLED:
		return va( "isn't filled by a plug %i units deep, flush with its surface", PORTAL_PLUG_DEPTH );
	case PR_OPEN_BEHIND:
		return "has no solid world behind its plug";
	case PR_NO_RIM:
		return "has no solid rim around it";
	case PR_BLOCKED_FRONT:
		return "has solid just in front of it";
	case PR_BLOCKED_VIS_POINT:
		return va( "has solid at its partner's visibility point, %i units in front of it", PORTAL_VIS_DISTANCE );
	default:
		return NULL;
	}
}

/*
================
BG_PortalEndWarning

Returns the warning about the rule ends[endNum] broke, naming it and its
position, or NULL if it broke none. An end sealed by its partner breaks none.
Two ends whose plugs overlap each other are warned about once, at the end
whose name sorts first
================
*/
static const char *BG_PortalEndWarning( const portalEnd_t *ends, int endNum ) {
	static char			warning[MAX_STRING_CHARS];
	const portalEnd_t	*end;
	const portalEnd_t	*other;
	const char			*rule;

	end = &ends[endNum];

	if ( end->rule == PR_PLUG_OVERLAP ) {
		other = &ends[end->overlap];
		if ( other->rule == PR_PLUG_OVERLAP && other->overlap == endNum
			&& Q_stricmp( other->targetname, end->targetname ) < 0 ) {
			return NULL;
		}
	}

	rule = BG_PortalEndRule( ends, endNum );
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
trap_GetEntityToken does. pointContents returns the contents of the world
alone at a point, with no entity in it. warn, unless it's NULL, is given a
warning for each rule an end breaks
================
*/
int BG_LoadPortalEnds( qboolean (*getToken)( char *buffer, int bufferSize ),
		int (*pointContents)( const vec3_t point ), void (*warn)( const char *warning ),
		portalEnd_t *ends, int maxEnds ) {
	const char	*warning;
	int			numFound;
	int			numEnds;
	int			i;

	numFound = BG_ReadPortalEnds( getToken, ends, maxEnds );
	numEnds = MIN( numFound, maxEnds );
	BG_CheckPortalEnds( pointContents, ends, numEnds );

	if ( !warn ) {
		return numEnds;
	}

	if ( numFound > numEnds ) {
		warn( va( S_COLOR_YELLOW "WARNING: the map has %i portal ends, and only the first %i are read\n",
			numFound, numEnds ) );
	}

	for ( i = 0 ; i < numEnds ; i++ ) {
		warning = BG_PortalEndWarning( ends, i );
		if ( warning ) {
			warn( warning );
		}
	}

	return numEnds;
}
