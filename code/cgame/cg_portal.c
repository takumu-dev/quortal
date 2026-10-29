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
// cg_portal.c -- the client's portal ends

#include "cg_local.h"

// a portal end's centre lies on its surface, where the light grid's samples
// are in the wall, so it's lit from this far in front, half the grid's
// usual spacing
#define	PORTAL_LIGHT_DISTANCE	32

/*
================
CG_PortalEndWarning
================
*/
static void CG_PortalEndWarning( const char *warning ) {
	CG_Printf( "%s", warning );
}

/*
================
CG_PortalEndContents

Returns the contents of the world alone at a point
================
*/
static int CG_PortalEndContents( const vec3_t point ) {
	return trap_CM_PointContents( point, 0 );
}

/*
================
CG_ReadPortalEnds

Reads the map's portal ends and checks them, with the server's own code, so
nothing about them needs to be sent. The server has already warned about the
rules they break, so the same warnings are printed here only for developers
================
*/
void CG_ReadPortalEnds( void ) {
	char	var[MAX_TOKEN_CHARS];
	int		i;

	trap_Cvar_VariableStringBuffer( "developer", var, sizeof( var ) );

	cgs.numPortalEnds = BG_LoadPortalEnds( trap_GetEntityToken, CG_PortalEndContents,
		atoi( var ) ? CG_PortalEndWarning : NULL, cgs.portalEnds, MAX_PORTAL_ENDS );

	// an end's shader is registered as a skin of one shader, as a model's
	// surfaces get theirs, so that a texture with no shader of its own is
	// lit as a model is, rather than drawn as a 2D picture
	for ( i = 0 ; i < cgs.numPortalEnds ; i++ ) {
		if ( cgs.portalEnds[i].shader[0] ) {
			cgs.portalEndSkins[i] = trap_R_RegisterSkin( cgs.portalEnds[i].shader );
		} else {
			cgs.portalEndSkins[i] = 0;
		}
	}
}

/*
================
CG_AddPortalEnds

Passes every portal end to the renderer, with its partner's frame if it
pairs. The renderer draws its surface: its shader, or flat black without one
================
*/
void CG_AddPortalEnds( void ) {
	portalEnd_t	*end;
	portalEnd_t	*partner;
	refEntity_t	ent;
	int			i;

	for ( i = 0 ; i < cgs.numPortalEnds ; i++ ) {
		end = &cgs.portalEnds[i];

		// an end with no usable frame isn't an end at all
		if ( end->state == PE_SKIPPED ) {
			continue;
		}

		memset( &ent, 0, sizeof( ent ) );
		ent.reType = RT_PORTAL;

		VectorCopy( end->origin, ent.origin );
		AxisCopy( end->axis, ent.axis );
		ent.halfWidth = end->width / 2;
		ent.halfHeight = end->height / 2;

		ent.renderfx = RF_LIGHTING_ORIGIN;
		VectorMA( end->origin, PORTAL_LIGHT_DISTANCE, end->axis[0], ent.lightingOrigin );

		if ( end->partner != -1 && cgs.portalEnds[end->partner].state != PE_SKIPPED ) {
			partner = &cgs.portalEnds[end->partner];
			VectorCopy( partner->origin, ent.partner.origin );
			AxisCopy( partner->axis, ent.partner.axis );
		}

		ent.customSkin = cgs.portalEndSkins[i];
		ent.shaderRGBA[0] = 255;
		ent.shaderRGBA[1] = 255;
		ent.shaderRGBA[2] = 255;
		ent.shaderRGBA[3] = 255;

		trap_R_AddRefEntityToScene( &ent );
	}
}
