import binascii
import hashlib
import hmac

from rest_framework import authentication, exceptions

from funkwhale_api.users.models import User


def get_token(salt, password):
    """Subsonic legacy token: MD5(password + salt). Required by the protocol."""
    to_hash = password + salt
    h = hashlib.md5()  # nosec B324 — Subsonic API mandates MD5
    h.update(to_hash.encode("utf-8"))
    return h.hexdigest()


def authenticate(username, password):
    try:
        if password.startswith("enc:"):
            password = password.replace("enc:", "", 1)
            password = binascii.unhexlify(password).decode("utf-8")
        user = (
            User.objects.all()
            .for_auth()
            .get(username__iexact=username, is_active=True, subsonic_api_token=password)
        )
    except (User.DoesNotExist, binascii.Error):
        raise exceptions.AuthenticationFailed("Wrong username or password.")

    if user.should_verify_email():
        raise exceptions.AuthenticationFailed("You need to verify your e-mail address.")

    return (user, None)


def authenticate_salt(username, salt, token):
    try:
        user = (
            User.objects.all()
            .for_auth()
            .get(username=username, is_active=True, subsonic_api_token__isnull=False)
        )
    except User.DoesNotExist:
        raise exceptions.AuthenticationFailed("Wrong username or password.")
    expected = get_token(salt, user.subsonic_api_token)
    # Constant-time compare so token content cannot be timed.
    # compare_digest requires equal length; unequal length is always a miss.
    provided = str(token or "")
    if len(provided) != len(expected) or not hmac.compare_digest(expected, provided):
        raise exceptions.AuthenticationFailed("Wrong username or password.")

    if user.should_verify_email():
        raise exceptions.AuthenticationFailed("You need to verify your e-mail address.")

    return (user, None)


class SubsonicAuthentication(authentication.BaseAuthentication):
    def authenticate(self, request):
        data = request.GET or request.POST
        username = data.get("u")
        if not username:
            return None

        p = data.get("p")
        s = data.get("s")
        t = data.get("t")
        if not p and (not s or not t):
            raise exceptions.AuthenticationFailed("Missing credentials")

        if p:
            return authenticate(username, p)

        return authenticate_salt(username, s, t)
