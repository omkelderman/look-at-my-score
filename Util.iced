MYSQL_DATE_STRING_REGEX = /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/
ISO_UTC_DATE_STRING_REGEX = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$/

convertDateStringToDateObject = (str) ->
    # lets trim cuz why not
    str = str.trim()

    # convert str into a date object.
    # two formats allowed:
    #   - a mysql-date-string (xxxx-xx-xx xx:xx:xx), asume UTC like osu api
    #   - ISO UTC string (xxxx-xx-xxTxx:xx:xx[.xxx]Z)
    if MYSQL_DATE_STRING_REGEX.test str
        # is mysql-date, lets convert it to an ISO string
        str = str.replace(' ', 'T')+'Z'
    else if not ISO_UTC_DATE_STRING_REGEX.test str
        # both not mysql date or iso date string, abort
        return null

    # convert to date object
    date = new Date str

    # the original string had a sortof valid ISO date format, but no idea yet if it is an actual valid date, so lets do a final check on that
    if isNaN date.getTime()
        # invalid date!
        return null

    # valid date!
    return date


module.exports.convertDateStringToDateObject = convertDateStringToDateObject
