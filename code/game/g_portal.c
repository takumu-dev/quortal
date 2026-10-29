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
// g_portal.c -- the server's portal ends

#include "g_local.h"

/*
================
G_PortalEndWarning
================
*/
static void G_PortalEndWarning( const char *warning ) {
	G_Printf( "%s", warning );
}

/*
================
G_PortalEndContents

Returns the contents at a point, which are the world's alone while nothing
is spawned
================
*/
static int G_PortalEndContents( const vec3_t point ) {
	return trap_PointContents( point, ENTITYNUM_NONE );
}

/*
================
G_ReadPortalEnds

Reads the map's portal ends and checks them, warning about every rule they
break. It reads the whole entity string, before the entities are spawned
from it, so that the ends are checked against the world alone
================
*/
void G_ReadPortalEnds( void ) {
	level.numPortalEnds = BG_LoadPortalEnds( trap_GetEntityToken, G_PortalEndContents, G_PortalEndWarning,
		level.portalEnds, MAX_PORTAL_ENDS );
}

/*
================
G_ListPortalEnds

Prints every portal end, with its verdict, for g_listPortalEnds
================
*/
void G_ListPortalEnds( void ) {
	portalEnd_t	*end;
	const char	*verdict;
	int			i;

	G_Printf( "%i portal ends:\n", level.numPortalEnds );

	for ( i = 0 ; i < level.numPortalEnds ; i++ ) {
		end = &level.portalEnds[i];

		if ( end->state == PE_OPEN ) {
			verdict = va( "open, paired with \"%s\"", end->target );
		} else if ( end->state == PE_SKIPPED ) {
			verdict = va( "skipped: it %s", BG_PortalEndRule( level.portalEnds, i ) );
		} else if ( end->rule != PR_NONE ) {
			verdict = va( "sealed: it %s", BG_PortalEndRule( level.portalEnds, i ) );
		} else {
			verdict = va( "sealed by its partner \"%s\"", end->target );
		}

		G_Printf( "%3i: \"%s\" at %s: %s\n", i, end->targetname, vtos( end->origin ), verdict );
	}
}
