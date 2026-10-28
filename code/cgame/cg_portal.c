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
CG_ReadPortalEnds

Reads the map's portal ends and checks them, with the server's own code, so
nothing about them needs to be sent. The server has already warned about the
rules they break, so the same warnings are printed here only for developers
================
*/
void CG_ReadPortalEnds( void ) {
	char	var[MAX_TOKEN_CHARS];

	trap_Cvar_VariableStringBuffer( "developer", var, sizeof( var ) );

	cgs.numPortalEnds = BG_LoadPortalEnds( trap_GetEntityToken, atoi( var ) ? CG_PortalEndWarning : NULL,
		cgs.portalEnds, MAX_PORTAL_ENDS );
}
