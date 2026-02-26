#if defined _gm_time_included
  #endinput
#endif
#define _gm_time_included

/**
 * Stock by [GM] NWC.
 *
 * @note You must add register_dictionary("gm_time.txt") in plugin_init()
 *
 * @param id    		The player whose language the length should be translated to
 * @param iSeconds		The number of time units you want translated into verbose text
 * @param output		The variable you want the verbose text to be placed in
 * @param outputLen		The length of the output variable
 *
 * @noreturn
 */

stock get_str_time(const id, iSeconds, output[], outputLen)
{
    new iLen, szText[128];

    new iDays = iSeconds / 86400;
    iSeconds -= iDays * 86400;
    new iHours = iSeconds / 3600;
    iSeconds -= iHours * 3600;
    new iMinutes = iSeconds / 60;
    iSeconds -= iMinutes * 60;

    if(iDays > 0)
    {
        if(iDays > 10 && ((iDays % 100) / 10) == 1)
        {
            iLen += formatex(szText[iLen], charsmax(szText) - iLen, "%L ", id, "GM_DAY_PLURAL", iDays);
        }
        else
        {
            switch(iDays % 10)
            {
                case 1: { iLen += formatex(szText[iLen], charsmax(szText) - iLen, "%L ", id, "GM_DAY_NOMINATIVE", iDays); }
                case 2, 3, 4: { iLen += formatex(szText[iLen], charsmax(szText) - iLen, "%L ", id, "GM_DAY_SINGULAR", iDays); }
                default: { iLen += formatex(szText[iLen], charsmax(szText) - iLen, "%L ", id, "GM_DAY_PLURAL", iDays); }
            }
        }
    }
    if(iHours > 0)
    {
        if(iHours > 10 && ((iHours % 100) / 10) == 1)
        {
            iLen += formatex(szText[iLen], charsmax(szText) - iLen, "%L ", id, "GM_HOUR_PLURAL", iHours);
        }
        else
        {
            switch(iHours % 10)
            {
                case 1: { iLen += formatex(szText[iLen], charsmax(szText) - iLen, "%L ", id, "GM_HOUR_NOMINATIVE", iHours); }
                case 2, 3, 4: { iLen += formatex(szText[iLen], charsmax(szText) - iLen, "%L ", id, "GM_HOUR_SINGULAR", iHours); }
                default: { iLen += formatex(szText[iLen], charsmax(szText) - iLen, "%L ", id, "GM_HOUR_PLURAL", iHours); }
            }
        }
    }
    if(iMinutes > 0)
    {
        if(iMinutes > 10 && ((iMinutes % 100) / 10) == 1)
        {
            iLen += formatex(szText[iLen], charsmax(szText) - iLen, "%L ", id, "GM_MINUTE_PLURAL", iMinutes);
        }
        else
        {
            switch(iMinutes % 10)
            {
                case 1: { iLen += formatex(szText[iLen], charsmax(szText) - iLen, "%L ", id, "GM_MINUTE_NOMINATIVE", iMinutes); }
                case 2, 3, 4: { iLen += formatex(szText[iLen], charsmax(szText) - iLen, "%L ", id, "GM_MINUTE_SINGULAR", iMinutes); }
                default: { iLen += formatex(szText[iLen], charsmax(szText) - iLen, "%L ", id, "GM_MINUTE_PLURAL", iMinutes); }
            }
        }
    }
    if(iSeconds > 0)
    {
        if(iSeconds > 10 && ((iSeconds % 100) / 10) == 1)
        {
            iLen += formatex(szText[iLen], charsmax(szText) - iLen, "%L ", id, "GM_SECOND_PLURAL", iSeconds);
        }
        else
        {
            switch(iSeconds % 10)
            {
                case 1: { iLen += formatex(szText[iLen], charsmax(szText) - iLen, "%L ", id, "GM_SECOND_NOMINATIVE", iSeconds); }
                case 2, 3, 4: { iLen += formatex(szText[iLen], charsmax(szText) - iLen, "%L ", id, "GM_SECOND_SINGULAR", iSeconds); }
                default: { iLen += formatex(szText[iLen], charsmax(szText) - iLen, "%L ", id, "GM_SECOND_PLURAL", iSeconds); }
            }
        }
    }

    formatex(output, outputLen, "%s", szText);
}