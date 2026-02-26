#include <amxmodx>
#include <reapi>

#pragma semicolon 1

public plugin_init()
{
	register_plugin("[ReAPI] Block 'Fire in the hole!'", "0.0.1", "sergrib");
	RegisterHookChain(RG_CBasePlayer_Radio, "fwdCBasePlayer_Radio", .post = false);
}

public fwdCBasePlayer_Radio(const iPlayer, const szMessageId[], const szMessageVerbose[], iPitch, bool:bShowIcon)
{
	#pragma unused iPlayer, szMessageId, iPitch, bShowIcon
	
	if (szMessageVerbose[0] == EOS)
		return HC_CONTINUE;
	
	if (szMessageVerbose[3] == 114) // 'r'
		return HC_SUPERCEDE;
	
	return HC_CONTINUE;
}