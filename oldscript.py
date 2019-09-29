import os
import sys
import json
import youtube_dl
import requests
from datetime import timedelta
from spotipy import Spotify
from spotipy.oauth2 import SpotifyClientCredentials
from time import sleep
from shutil import copyfileobj, rmtree
from uuid import uuid4
from yaspin import kbi_safe_yaspin, Spinner
from termcolor import colored
from progressbar import progressbar
from subprocess import run, call, DEVNULL, PIPE

#TODO: keep updating based on file changes (aka add new added lines to the queue) by putting the lines outside the for loop inside a get_tracklist func & using a while loop with a to_download list instead
#TODO: asyncio downloads, spinner.write does not change, spinner.text has a global progressbar based on current [xxx/xxx]
#TODO: Pull from google docs or spotify w/ a subcommand
#TODO: put out_dir, file to get searches from, separator for searches, separator for downloaded file name & others as constants up top, make a ~/.config/pbytdl/config.yaml to house them all, make a config subcommand to read/write to it
#TODO: subcommand to get/add/remove/replace entries in the file
#TODO: subcommand to validate a file (check for format errors)
#TODO: delete currently downloading file when the script is Ctrl-C'ed, make a shortcut to 'shutdown gracefully' and bind Ctrl-C to graceful_shutdown
#TODO: "clean" subcommand Compare w/ files in other dir(s) that have the same artist+title (case insensitive + fuzzy match) & choose via a prompt which one to keep
#TODO: try next video if the first one is too long
#TODO: subcommand 'batch' for this regular mode
#TODO: error reporting @ the end (which files failed, (why)?)
#TODO: subcommand 'single' for a simple one-off search (not the same CLI tho)
#TODO: verbosity options to just print JSON info about the downloads
#TODO: --dry-run or --simulate ?
#TODO: kb shortcut to skip current file download only
#TODO: hot-reload config

# Constants
# ---------------------------------------------------
OUT_DIR = '/mnt/d/#/Music/ytdl'
IN_FILE = '/mnt/d/#/Documents/music-i-liek.txt'
MAX_TIME_DELTA_SECONDS = 30

# Init
# ---------------------------------------------------
spotify_credentials_mgr = SpotifyClientCredentials(client_id="b6ba0ee2cd66405a8adbb3069b5f2e76", client_secret="181dc2e5565a4b6e9d5747a608e57a4a")
spotify = Spotify(client_credentials_manager=spotify_credentials_mgr)

# Shortcuts & utils
# ---------------------------------------------------
from pyparsing import *

ESC = Literal('\x1b')
integer = Word(nums)
escapeSeq = Combine(ESC + '[' + Optional(delimitedList(integer,';')) + 
                oneOf(list(alphas)))

no_ansi = lambda s : Suppress(escapeSeq).transformString(s)
def red(o):
    return colored(str(o), 'red')

def yellow(o):
    return colored(str(o), 'yellow')

def bold(o):
    return colored(str(o), attrs=['bold'])

def ellipsis(string, maxlength):
    maxlength -= 1
    if len(string) >= maxlength:
        return string[:maxlength] + '…'
    else:
        return string

def fit_text_to_length(string, maxlength, align_to='left', color=None, attrs=None):
    attrs = [] if attrs is None else attrs
    invisible_chars_len = len(string) - len(no_ansi(string))

    spaces_to_add = maxlength - len(no_ansi(string))
    if spaces_to_add < 0:
        return ellipsis(string, maxlength)
    else:
        if align_to == 'right':
            return '{string:>{maxlen}}'.format(string=string, maxlen=maxlength+invisible_chars_len)
        elif align_to == 'center':
            return '{string:^{maxlen}}'.format(string=string, maxlen=maxlength+invisible_chars_len)
        else:
            return '{string:{maxlen}}' .format(string=string, maxlen=maxlength+invisible_chars_len)
        
def human_filesize(bytessize):
    for unit in ['','Ki','Mi','Gi','Ti','Pi','Ei','Zi']:
        if abs(bytessize) < 1024.0:
            return "%3.1f%s%s" % (bytessize, unit, 'B')
        bytessize /= 1024.0
    return "%.1f%s%s" % (bytessize, 'Yi', 'B')



# Get file
def get_all_tracks():
    with open(IN_FILE, 'r') as file:
        return [l.replace('\n','').strip() for l in file.readlines() if l.replace('\n','').strip()]

def strip_comments(tracklist):
    return [l for l in tracklist if not l.startswith('#')]

#TODO: Use a ordered set instead
def strip_duplicates(tracklist):
    seen = set()
    seen_add = seen.add
    return [x for x in tracklist if not (x in seen or seen_add(x))]

def strip_unvalid(tracklist, print_howto=True):
    ret = []
    print_howto
    for track in tracklist:
        if not ' - ' in track:
            print(colored('ERR!', 'white', 'on_red'), red('The track'), bold(track), red("does not have a correct format, ignoring entry."))
            if print_howto:
                print(red ('     Please use the following format to specify your tracks:' ))
                print(bold('                      Artist - Track title'                   ))
                print(red ('     Note the spaces surrounding the dash, they\'re required.'))
            print_howto = False
        else:
            ret.append(track)
    
    return ret

def get_filename(metadata):
    return f"{metadata['artist']} - {metadata['title']}"

def is_already_downloaded(track):
    filename = get_filename(get_metadata(track))+'.mp3'
    return os.path.isfile(os.path.join(OUT_DIR, filename))

def strip_already_downloaded(tracklist):
    return [l for l in tracklist if not is_already_downloaded(l)]

def to_mp3(path):
    new_path = path+'-converted'
    
    completed = run(["ffmpeg",
                    "-loglevel", "quiet",
                    "-hide_banner", "-y",
                    "-i", path,
                    "-write_id3v1", "1",
                    "-id3v2_version", "3",
                    "-codec:a", "libmp3lame",
                    "-q:a", "3",
                    new_path],
                    stderr=DEVNULL, stdout=DEVNULL, stdin=PIPE
                    )
    
    
    if completed.returncode == 0:
        call(['rm', path]) # remove the original file once transcoded
        call(['mv', new_path, path]) # rename the new file with the original file's name

def get_spotify_match(search_query):
    matches = spotify.search(search_query, limit=5, type='track')
    matches = matches['tracks']['items']
    if not len(matches): return None

    idx = None
    for i, match in enumerate(matches):
        if match['album']['album_type'] == 'compilation':
            continue
        idx = i
        break
    if idx is None: idx = 0

    return matches[idx]


def get_spotify_metadatas(search_query):

    track = get_spotify_match(search_query)
    
    if track is None: return {}
    album = track['album']

    return {
        'album': album['name'],
        'total_tracks': album['total_tracks'],
        'release_date': album['release_date'],
        'track_number': track['track_number'],
        'duration'    : int(track['duration_ms']) // 1000
    }


def get_cover_art(search_query):
    cover_art_dir = os.path.abspath(os.path.join(OUT_DIR, '.pbytdl', 'cover-arts'))
    os.makedirs(cover_art_dir, exist_ok=True)

    track = get_spotify_match(search_query)

    if track is None: return None
    images = track['album']['images']
    if not len(images): return None

    try:
        cover_art_url  = images[1]['url']
    except IndexError:
        cover_art_url  = images[0]['url']

    cover_art_file = os.path.split(cover_art_url.replace('https://i.scdn.co/', ''))[1]
    cover_art_filepath = os.path.join(cover_art_dir, cover_art_file+'.png')

    if os.path.isfile(cover_art_filepath):
        return cover_art_filepath
    
    cover_art_resp = requests.get(cover_art_url, stream=True)

    with open(cover_art_filepath, 'wb') as file:
        copyfileobj(cover_art_resp.raw, file)
    
    return cover_art_filepath

def get_full_metadata(search_query):
    artist, title  = search_query.split(' - ')
       
    return {
        'artist': artist, 
        'title': title,
        'cover_art': get_cover_art(search_query),
        **get_spotify_metadatas(search_query)
    }

def get_metadata(search_query):
    artist, title  = search_query.split(' - ')
       
    return {
        'artist': artist, 
        'title': title,
    }


def apply_metadata(filepath, metadata, try_to_convert=True, errors_hook=print):
    import eyed3
    
    file = eyed3.load(filepath)
    if file.tag == None:
        file.initTag()
    
    file.tag.artist = file.tag.album_artist = metadata['artist']
    file.tag.title  = metadata['title']
    try:
        file.tag.album  = metadata['album']
        file.tag.track_num = metadata['track_number']
        file.tag.track_total = metadata['total_tracks']
        file.tag.year   = metadata['release_date'].split('-')[0]  # Assuming YYYY-MM-DD
        file.tag.images.set(3, open(metadata['cover_art'], 'rb').read(), 'image/png')
    except KeyError:
        errors_hook(('Can\'t apply other tags to ', ': not found on Spotify.'))

    file.tag.save()

def comment_out(track, cause=''):
    with open(IN_FILE, 'r') as file:
        lines = [l.strip() for l in file.read().split('\n')]

    def operator(line):
        if line.strip().lower() == track.strip().lower():
            return '# ' + line + f"  [deactivated{': ' if cause else ''}{cause}]"
        return line
    
    new_lines = [operator(line) for line in lines]

    with open(IN_FILE, 'w') as file:
        file.write('\n'.join(new_lines))


def get_duration(filepath, total=False):
    """ Returns a tuple containing (minutes, seconds)
    """
    from eyed3 import load
    tot = load(filepath).info.time_secs
    return tot if total else (round(t) for t in divmod(tot, 60))

def check_durations(filepath, metadata):
    """ 
    Compare the metada's duration (obtained from Spotify)
    with the actual duration of the file.

    If the difference is greater than MAX_TIME_DELTA_SECONDS, return False.
    return True otherwise
    """

    expected = metadata.get('duration', None)
    if expected is None: return True

    actual   = get_duration(filepath, total=True)

    return abs(expected - actual) <= MAX_TIME_DELTA_SECONDS


def clean_temp_files():
    dir_to_rm = os.path.join(OUT_DIR, '.pbytdl', 'download')
    try:
        num_deleted = len(os.listdir(dir_to_rm))
    except FileNotFoundError:
        return 0
    
    rmtree(dir_to_rm, ignore_errors=True)
    return num_deleted

def full_clean():
    dir_to_rm = os.path.join(OUT_DIR, '.pbytdl')
    try:
        num_deleted = len(os.listdir(dir_to_rm))
    except FileNotFoundError:
        return 0
    
    rmtree(dir_to_rm, ignore_errors=True)
    return num_deleted

#TODO: Write to .../.pbytdl & move back after youtube-dl finished
def ytdl(metadata, search_query):
    """
    Download videos using youtube-dl.
    I can't use the python implementation since ID3 tag headers are broken,
    and not repairable by mutagen's .add_tags (raises HeadersNotFound: Can't sync MPEG Frames)
    """

    write_dir = os.path.join(OUT_DIR, '.pbytdl', 'download')
    os.makedirs(write_dir, exist_ok=True)
    filename = f"{get_filename(metadata)}.%(ext)s"
    write_path_template = os.path.join(write_dir, filename)
    write_path = write_path_template % {'ext': 'mp3'}
    final_path = os.path.join(OUT_DIR,   filename % {'ext': 'mp3'})

    os.chdir(write_dir)
    skipped = False
    if os.path.isfile(final_path):
        skipped = True
    else:
        call(['youtube-dl',
              '-xq',
              '--audio-format', 'mp3',
              '--output', write_path_template,
              '--default-search', 'ytsearch',
              '--console-title',
              search_query])
    if os.path.isfile(write_path):
        os.rename(write_path, final_path)
    else:
        skipped = True
    return final_path, skipped

def table_row(columns, row, separator_additional_width=(4,4), color='white'):
    cols = []
    default_column_conf = {
        'name': '',
        'align': 'left',
        'width': None
    }
    for column in columns:
        col = {**default_column_conf, **column}
        if col['width'] is None:
            col['width'] = max([1, len(col['name'])])
        col['content'] = colored(row.get(col['id'], bold('(unknown)')), color)
        cols.append(col)

    row_text = separator_additional_width[0] * ' ' + '%s' + separator_additional_width[1] * ' '
    row_text = row_text % '  '.join(fit_text_to_length(c['content'], c['width']) for c in cols)
    return row_text

#TODO: dynamic columns width based on term width percentage (by specifying width: 0.5 or sth under '1')
#TODO: new func to get full columns config (code is re-used in table_header and ..._row)
def table_header(columns, separator='—', separator_additional_width=(4,4)):
    """
    Creates a table header using the specified columns, that is a list of dicts:
    {
        'name': '',
        'align': 'left',
        'width': None
    }
    If width is set to None, it'll be calculated from the name length.
    """
    cols = []
    default_column_conf = {
        'name': '',
        'align': 'left',
        'width': None
    }

    for column in columns:
        col = {**default_column_conf, **column}
        if col['width'] is None:
            col['width'] = max([1, len(col['name'])])
        cols.append(col)

    header_text = separator_additional_width[0] * ' ' + '%s' + separator_additional_width[1] * ' '
    header_text = header_text % '  '.join(fit_text_to_length(c['name'], c['width']) for c in cols)

    total_width = separator_additional_width[0] + len(header_text) + separator_additional_width[1]
    header_sep  = total_width * separator

    return header_text + '\n' + header_sep


def get_tracks():
    tracks = strip_comments(get_all_tracks())
    tracks_all = tracks
    tracks = strip_unvalid(tracks)
    invalids_count = len(tracks_all) - len(tracks)
    tracks = strip_already_downloaded(tracks)
    already_downloadeds_count = len(tracks_all) - len(tracks)

    return tracks, {
        'all': len(tracks_all),
        'invalids': invalids_count,
        'already_downloadeds': already_downloadeds_count,
        'to_downloads': len(tracks)
    }

def print_tracklist_counts(counts):
    all_tracks = counts['all']
    invalids = counts['invalids']
    already_downloadeds = counts['already_downloadeds']
    to_downloads = counts['to_downloads']

    print(f"{red(all_tracks)} tracks")
    if invalids:
        print(f"∟ {red(invalids)} unvalid entries")
    if already_downloadeds: 
        print(f"∟ {red(already_downloadeds)} tracks already downloaded")
    if invalids or already_downloadeds: 
        print(f"∟ {red(to_downloads)} tracks to download")

def updated_tracklist_counts_msg(counts):
    return f"Detected {red(counts['to_downloads'])} new tracks to download"

def print_silly_init_msg():
    print(colored('Booting up the hyper-dimensional download engine cores...', attrs=['dark']))
    print(colored('Mutating the state matrix to acquire the YouTube metadata tesseracts...', attrs=['dark']))
    print('')

def table_demo():
    columns = [
        { 'id': 'status_icon',                      'width': 1   },
        { 'id': 'artist',      'name' : 'Artist',   'width': 50  },
        { 'id': 'track',       'name' : 'Track',    'width': 80  },
        { 'id': 'album',       'name' : 'Album',    'width': 50  },
        { 'id': 'duration',    'name' : 'Duration', 'width': 10  },
        { 'id': 'file_size',   'name' : 'File size'              },
    ]

    print(table_header(columns))
    print(table_row(columns, {
        'status_icon': '✓',
        'artist': 'Jeremy Blake',
        'track': 'Like the World is New',
        'album': 'Juvenile Hyperobject',
        'duration': '03:45',
        'file_size': '3.21 MiB'
    }, color='green'))
    sleep(0.5)
    print(table_row(columns, {
        'status_icon': yellow('~'),
        'artist': 'Mx3',
        'track': 'Tesseract',
        # 'album': 'Juvenile Hyperobject',
        'duration': '03:45',
        'file_size': '3.21 MiB'
    }))
    sleep(0.5)
    print(table_row(columns, {
        'status_icon': '✓',
        'artist': 'Jeremy Blake',
        'track': 'Like the World is New',
        # 'album': 'Juvenile Hyperobject',
        'duration': '03:45',
        'file_size': '3.21 MiB'
    }))


if __name__ == "__main__":
    table_demo()
    # Clean temp data
    num_deleted = clean_temp_files()
    if num_deleted: print(f"Deleted {red(num_delet
    ed)} file{'s' if num_deleted > 1 else ''} temporary files.")
    # Init data
    tracks, counts = get_tracks()
    print_tracklist_counts(counts)
    if not counts['to_downloads']:
        print(f'Nothing to download! Add some tracks in {bold("mnt/d/#/Documents/music-i-liek.txt")} and try again')
        sys.exit()
    # Init counters
    downloaded_count = 0
    failed_count = 0
    skipped_count = 0

    #TODO: box listing constants key/val pairs
    print_silly_init_msg()

    while len(tracks) > 0:
        track = tracks[0]

        # TODO hide cursor during this
        with kbi_safe_yaspin() as sp:
            def err_hook(msg, critical=False): 
                color = red if critical else yellow
                sp.text = spinner_text % (color(msg[0]), color(msg[1]))
                sleep(1.5)

            metadata = get_metadata(track)
            nth_dl  = '{current:>{total_strlen}}/{total}'.format(current=downloaded_count+1, total=counts['to_downloads'], total_strlen=len(str(counts['to_downloads'])))
            #TODO: this to a function that takes Artist - Track and ouputs cyan<bold<Artist> Track>
            track_pretty = colored(metadata["artist"], "cyan", attrs=["bold"]) + ' ' + colored(metadata["title"], "cyan")
            spinner_text = f"[{nth_dl}] %s{track_pretty}%s"
            # TODO: Use a table instead with download #, status (icon mode or skipped, cancelled, downloaded, metadata-only), artist, title, album (dark<(unknown)> if None), duration (±duration delta), filesize
            spinner_write = ' ' * len(f"[{nth_dl}] ") + '> %s'


            sp.text = spinner_text % ('Downloading ', '...')
            filepath, skipped = ytdl(metadata, track)
            if skipped:
                sp.text = spinner_text % ('Skipping download for ', '...')
                skipped_count += 1
            
            metadata = get_full_metadata(track)
            sp.text = spinner_text % ('Comparing durations for ', '...')
            validated = check_durations(filepath, metadata)
            if not validated:
                #TODO: retry w/ next video instead of just giving up or (better) choose immediately the video that matches the most the expected duration
                err_hook(('Error while comparing durations for ', ': removing file...'), critical=True)
                os.remove(filepath)
                comment_out(track, cause='Downloaded file was either too long or too short when compared to Spotify data')
                sp.write(spinner_write % f'{yellow("Cancelled downloading of")} "{track_pretty}" {yellow("(error while comparing durations)")}')

            if validated:
                sp.text = spinner_text % ('Applying metadata to ', '...')
                apply_metadata(filepath, metadata, errors_hook=err_hook)

                verb = 'Applied metadata' if skipped else 'Downloaded'
                duration_m, duration_s = get_duration(filepath)
                duration_fmt = "{m:02}:{s:02}".format(m=duration_m, s=duration_s)
                size = os.stat(filepath).st_size
                size_fmt = human_filesize(size)
                sp.write(spinner_write % f'{verb} "{track_pretty}" ({yellow(duration_fmt)} for {yellow(size_fmt)})')

            if not skipped:
                downloaded_count += 1
            
            tracks.pop(0)

            prev_counts = counts
            prev_tracks = tracks
            tracks, counts = get_tracks()
            new_tracks = [track for track in tracks if track not in prev_tracks]
            if len(new_tracks):
                sp.write(spinner_write % f'Detected {red(len(new_tracks))} new track{"s" if len(new_tracks) > 1 else ""}: {ellipsis(", ".join(new_tracks), 50)}')

    print(colored('-' * 30))
    print('')
    print(f"Downloaded {downloaded_count}/{counts['to_downloads']} files")
