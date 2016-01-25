# How to add a new event

**The easiest way** to submit an event is to use the Google Form: <https://docs.google.com/forms/d/1L2tMc9mWZy62lNrXQsbhQmMF5pLKgfXZoDfF_z0ePKk/viewform>

To add a new event manually you can submit a pull request with the information of the event
added to one of the `json` files in this directory. Once accepted
the page will be updated and your event will be visible.

Events are organized by their starting year. Choose the `json` file that
corresponds to the year when your event starts, if the file doesn't exist yet
then you can create it.

For example, let's create a new event that starts *May 4th, 2014 at 12pm* and
lasts 10 days.

You'll need to create a new object in the `jams` array, the position doesn't
matter but for simplicity keep things in ascending order of start date.

If you are specifying a time in addition to the date for your start and end then
you should provide a timezone (otherwise it defaults to UTC). More information
on times and dates below.

The following fields are required: `name`,  `url`, `start_date`, `end_date`.

**jams/2014.json**

    {
      jams: [
        .. other events ..,

        {
          "name": "My cool event",
          "url": "http://example.com/my-event",
          "start_date": "2014-05-04 12:00 +0200",
          "end_date": "2014-05-14 12:00 +0200"
        }
      ]
    }



Optionally you can provide the fields `description` and/or `image`.
Here's a more complete version of the above example:

**jams/2014.json**

    {
      jams: [
        .. other events ..,

        {
          "name": "My cool event",
          "url": "http://example.com/my-event",
          "start_date": "2014-05-04 12:00 +0200",
          "end_date": "2014-05-14 12:00 +0200",
          "description": "This is the event we've been waiting for, I hope you are ready. I know I am!"
        }
      ]
    }

### Date and time format

The following patterns are supported for parsing dates. If either the start or
end can't be parsed then the event entry is invalid.

    YYYY-MM-DD HH:mm:ss Z
    YYYY-MM-DD HH:mm Z
    YYYY-MM-DD


`Z` means timezone, in the form `+0000`. All StadiNyt events **must** be in the Helsinki metropolitan area, so you must use the timezone `+0200`for wintertime events and `+0300` for Daylight Saving Time events. You must
provide 2 digits for day, month, or seconds even when they are less than 10. So
`05` for May, `01` for the first day of the month, etc.

The final format `YYYY-MM-DD` is special, there is no time or timezone. This
will cause the event's start time to be `0:00` and end time to be `23:59` in the
viewer's local time zone on the respective days passed in. That makes an
inclusive range from start to end.

### Editing an existing event

If you are familiar with JSON and GitHub, feel free to edit any existing events, and to fix any errors.
