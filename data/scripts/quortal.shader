// Fills a portal end's opening, flush with the surface around it, and 64
// units deep. It's never drawn, and isn't solid: what stops a trace at it
// is its own contents bit, which every trace mask includes
textures/quortal/plug
{
	qer_editorimage textures/quortal/plug.png
	qer_trans 0.5
	surfaceparm nonsolid
	surfaceparm nodraw
	surfaceparm detail
	surfaceparm plug
}
