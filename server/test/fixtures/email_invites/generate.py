"""Generates the DKIM-signed .eml fixtures used by the email invite tests.

Signing is done with dkimpy (an independent DKIM implementation), so the tests check
our verifier against real signatures rather than against itself. A fresh throwaway
key pair is made on every run; only the public keys are written (dns_txt.txt).

    python3 -m venv /tmp/venv && /tmp/venv/bin/pip install dkimpy
    /tmp/venv/bin/python test/fixtures/email_invites/generate.py
"""

import base64
import os
import subprocess
import tempfile

import dkim

HERE = os.path.dirname(os.path.abspath(__file__))


def keypair():
    with tempfile.TemporaryDirectory() as tmp:
        private = os.path.join(tmp, "key.pem")
        subprocess.run(["openssl", "genrsa", "-out", private, "2048"], check=True, capture_output=True)
        der = subprocess.run(
            ["openssl", "rsa", "-in", private, "-pubout", "-outform", "DER"],
            check=True,
            capture_output=True,
        ).stdout
        with open(private, "rb") as f:
            return f.read(), base64.b64encode(der).decode()


def crlf(text):
    return text.replace("\r\n", "\n").replace("\n", "\r\n").encode()


def b64(data, width=76):
    encoded = base64.b64encode(data.encode()).decode()
    return "\n".join(encoded[i : i + width] for i in range(0, len(encoded), width))


INVITE_GOOGLE = """BEGIN:VCALENDAR
PRODID:-//Google Inc//Google Calendar 70.9054//EN
VERSION:2.0
CALSCALE:GREGORIAN
METHOD:REQUEST
BEGIN:VEVENT
DTSTART;TZID=Europe/London:20261205T140000
DTEND;TZID=Europe/London:20261205T160000
DTSTAMP:20261113T120000Z
ORGANIZER;CN=Swim Club:mailto:club@swim.example
UID:5q3n0v9ld0kq8m2kj1b6fhd7c4@google.com
SEQUENCE:0
STATUS:CONFIRMED
SUMMARY:Swimming gala
LOCATION:Leisure centre\\, Pool 2
DESCRIPTION:Bring goggles and a towel.
END:VEVENT
END:VCALENDAR
"""

INVITE_OUTLOOK = """BEGIN:VCALENDAR
METHOD:REQUEST
PRODID:Microsoft Exchange Server 2010
VERSION:2.0
BEGIN:VTIMEZONE
TZID:GMT Standard Time
BEGIN:STANDARD
DTSTART:16010101T020000
TZOFFSETFROM:+0100
TZOFFSETTO:+0000
RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=-1SU;BYMONTH=10
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:16010101T010000
TZOFFSETFROM:+0000
TZOFFSETTO:+0100
RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=-1SU;BYMONTH=3
END:DAYLIGHT
END:VTIMEZONE
BEGIN:VEVENT
ORGANIZER;CN=Hill School Office:mailto:office@hillschool.example
DESCRIPTION;LANGUAGE=en-GB:Parents are invited to the end of term assembly. Ple
 ase arrive by 9:15.
UID:040000008200E00074C5B7101A82E0080000000070D6F2B0D35BDB01000000000000000010
 000000C8A9B6B4C2A5E14D9C7D8E2F0A1B3C4D
SUMMARY;LANGUAGE=en-GB:End of term assembly
DTSTART;TZID=GMT Standard Time:20261218T091500
DTEND;TZID=GMT Standard Time:20261218T103000
CLASS:PUBLIC
PRIORITY:5
DTSTAMP:20261113T120000Z
TRANSP:OPAQUE
STATUS:CONFIRMED
SEQUENCE:0
LOCATION;LANGUAGE=en-GB:School hall
END:VEVENT
END:VCALENDAR
"""

INVITE_FORWARDED = """BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Apple Inc.//macOS 15.0//EN
METHOD:REQUEST
BEGIN:VEVENT
UID:B1C2D3E4-F5A6-4B7C-8D9E-0F1A2B3C4D5E
DTSTART;VALUE=DATE:20261224
DTEND;VALUE=DATE:20261227
SUMMARY:Christmas at Gran's
SEQUENCE:0
END:VEVENT
END:VCALENDAR
"""

# Gmail-style: invite inline (text/calendar) and attached (invite.ics), relaxed/relaxed.
GMAIL_STYLE = f"""From: Mum <mum@family.example>
To: app@portermills.net
Subject: Fwd: Invitation: Swimming gala @ Sat 5 Dec 2026
 2pm - 4pm (GMT)
Date: Fri, 13 Nov 2026 12:00:00 +0000
Message-ID: <gmail-style@family.example>
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="000000000000outer"

--000000000000outer
Content-Type: multipart/alternative; boundary="000000000000inner"

--000000000000inner
Content-Type: text/plain; charset="UTF-8"

---------- Forwarded message ---------
Swimming gala   with  extra   spaces
Saturday 5 Dec 2026 2pm - 4pm (GMT)

--000000000000inner
Content-Type: text/html; charset="UTF-8"

<div>Swimming gala</div>

--000000000000inner
Content-Type: text/calendar; charset="UTF-8"; method=REQUEST
Content-Transfer-Encoding: base64

{b64(INVITE_GOOGLE)}
--000000000000inner--

--000000000000outer
Content-Type: application/ics; name="invite.ics"
Content-Disposition: attachment; filename="invite.ics"
Content-Transfer-Encoding: base64

{b64(INVITE_GOOGLE)}
--000000000000outer--


"""

# Outlook-style: quoted-printable text/calendar with a Windows TZID, simple/simple.
OUTLOOK_STYLE = """From: "Dad" <dad@family.example>
To: "Portermills" <app@portermills.net>
Subject: FW: End of term assembly
Date: Fri, 13 Nov 2026 12:05:00 +0000
Message-ID: <outlook-style@family.example>
MIME-Version: 1.0
Content-Type: multipart/alternative;
\tboundary="_000_outlook_"

--_000_outlook_
Content-Type: text/plain; charset="us-ascii"
Content-Transfer-Encoding: quoted-printable

Forwarding the assembly invite.

--_000_outlook_
Content-Type: text/calendar; charset="utf-8"; method=REQUEST
Content-Transfer-Encoding: quoted-printable

""" + INVITE_OUTLOOK.replace("=", "=3D").replace(
    "Parents are invited to the end of term assembly. Ple\n ase arrive by 9:15.",
    "Parents are invited to the end of term assembly. Ple=\n\n ase arrive by 9:15.",
) + """
--_000_outlook_--
"""

# Apple Mail "forward as attachment": the invite is inside a message/rfc822 part.
FORWARDED_AS_ATTACHMENT = f"""From: mum@family.example
To: app@portermills.net
Subject: Fwd: Christmas
Date: Fri, 13 Nov 2026 12:10:00 +0000
Message-ID: <forwarded@family.example>
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="Apple-Mail=_outer"

--Apple-Mail=_outer
Content-Type: text/plain; charset=us-ascii

See attached.

--Apple-Mail=_outer
Content-Type: message/rfc822; name="Christmas.eml"
Content-Disposition: attachment; filename="Christmas.eml"

From: Gran <gran@elsewhere.example>
To: mum@family.example
Subject: Christmas
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="inner-boundary"

--inner-boundary
Content-Type: text/plain

Come for Christmas!

--inner-boundary
Content-Type: text/calendar; method=REQUEST; name="invite.ics"
Content-Transfer-Encoding: 7bit

{INVITE_FORWARDED}
--inner-boundary--

--Apple-Mail=_outer--
"""

# A signed email from a family member with no invite in it.
NO_INVITE = """From: Mum <mum@family.example>
To: app@portermills.net
Subject: Did the invite arrive?
Date: Fri, 13 Nov 2026 12:15:00 +0000
Message-ID: <no-invite@family.example>
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii

Just checking!
"""

# What Fastmail adds on top when it receives the mail and forwards it on to Postmark.
FASTMAIL_FORWARD_HEADERS = """Received: from compute1.internal (compute1.nyi.internal [10.202.2.41])
\tby mailforward.example (Postfix) with ESMTP id 1234ABCD
\tfor <abc123@inbound.postmarkapp.com>; Fri, 13 Nov 2026 07:00:01 -0500 (EST)
X-ME-Sender: <xms:abc>
Delivered-To: app@portermills.net
"""


def sign(message, private_key, domain, selector, canonicalize, headers=None):
    headers = headers or [b"from", b"to", b"subject", b"date", b"message-id", b"mime-version", b"content-type"]
    signature = dkim.sign(
        message,
        selector.encode(),
        domain.encode(),
        private_key,
        canonicalize=canonicalize,
        include_headers=headers,
    )
    signed = signature + message
    assert dkim.verify(signed, dnsfunc=lambda name, timeout=5: dns[name.decode() if isinstance(name, bytes) else name])
    return signed


def write(name, data):
    with open(os.path.join(HERE, name), "wb") as f:
        f.write(data)


family_key, family_pub = keypair()
attacker_key, attacker_pub = keypair()

dns = {
    "sel1._domainkey.family.example.": f"v=DKIM1; k=rsa; p={family_pub}".encode(),
    "evil._domainkey.attacker.example.": f"v=DKIM1; k=rsa; p={attacker_pub}".encode(),
}

write(
    "gmail_style.eml",
    crlf(FASTMAIL_FORWARD_HEADERS)
    + sign(crlf(GMAIL_STYLE), family_key, "family.example", "sel1", (b"relaxed", b"relaxed")),
)
write(
    "outlook_style.eml",
    sign(crlf(OUTLOOK_STYLE), family_key, "family.example", "sel1", (b"simple", b"simple")),
)
write(
    "forwarded_as_attachment.eml",
    sign(crlf(FORWARDED_AS_ATTACHMENT), family_key, "family.example", "sel1", (b"relaxed", b"simple")),
)
write(
    "no_invite.eml",
    sign(crlf(NO_INVITE), family_key, "family.example", "sel1", (b"relaxed", b"relaxed")),
)
# A real signature, but from a domain that has nothing to do with the From address.
write(
    "unaligned_signature.eml",
    sign(crlf(GMAIL_STYLE), attacker_key, "attacker.example", "evil", (b"relaxed", b"relaxed")),
)

with open(os.path.join(HERE, "dns_txt.txt"), "w") as f:
    for name, value in dns.items():
        f.write(f"{name.rstrip('.')} {value.decode()}\n")

print("wrote fixtures to", HERE)
