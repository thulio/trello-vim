if !has('python')
    echo "Error: Requires vim compiled with python"
    finish
endif

function! CreateTrelloBuffer()
    let bn = bufnr('trello')
    if bn > 0
        let wi=index(tabpagebuflist(tabpagenr()), bn)
        if wi >= 0
            silent execute (wi+1).'wincmd w'
        else
            silent execute 'vsp | b '.bn
        endif
    else
        vsplit 'trello'
    endif

    setlocal modifiable
    setlocal noswapfile
    setlocal ft=markdown
    setlocal buftype=nofile
endfunction

function! Cards(boardName)
python << EOF
import vim
import urllib2
import os
import json
import codecs

CON_FILE = '.trello-vim'

with open(os.path.expanduser('~') + '/' + CON_FILE) as f:
    configs = json.loads(f.read())

board_name = vim.eval('a:boardName').decode('utf-8')

SHOW_CARD_URL = configs['url']
SHOW_LABELS = configs['label']
SHOW_DONE_CARDS = configs['done_cards']

KEY_TOKEN = {'key': configs['key'], 'token': configs['token']}
BOARDS_URL = 'https://trello.com/1/members/me/boards?key={key}&token={token}'.format(**KEY_TOKEN)
LISTS_URL = 'https://api.trello.com/1/boards/{id}/lists?key={key}&token={token}&cards=all'
CARDS_URL = 'https://trello.com/1/members/my/cards?key={key}&token={token}'.format(**KEY_TOKEN)

try:
    boards_request = json.loads(urllib2.urlopen(BOARDS_URL).read())
    selected_board = None
    for board in boards_request:
        if board['name'].encode('utf-8').lower() == board_name.encode('utf-8').lower():
            selected_board = board
            break
    if selected_board is None:
        raise ValueError('Board not found %s' % board_name.encode('utf-8'))

    vim.command('call CreateTrelloBuffer()')
    del vim.current.buffer[:]
    vim.current.buffer[0] = "Cards in board %s" % board['name'].encode('utf-8')
    vim.current.buffer.append(35 * "=")

    columns = {}
    lists_request = json.loads(urllib2.urlopen(LISTS_URL.format(key=configs['key'], token=configs['token'], id=selected_board[u'id'])).read())
    for tlist in lists_request:
        list_name = tlist['name']
        vim.current.buffer.append("# %s" % list_name.encode('utf-8'))

        for card in tlist[u'cards']:
            name = card['name'].encode("UTF-8")
            url = card['url'].encode("UTF-8")

            if SHOW_DONE_CARDS or list_name != 'Done':
                vim.current.buffer.append("- %s" % name)

                if SHOW_LABELS:
                    labels = []
                    for label in card['labels']:
                        labels.append(label['name'].encode('UTF-8') or label['color'].encode('UTF-8'))
                    all_labels = ', '.join(labels)
                    if all_labels:
                        vim.current.buffer.append("  - Labels: %s" % all_labels)

                if SHOW_CARD_URL:
                    vim.current.buffer.append("  - URL: %s" % url)

                vim.current.buffer.append('\n')

        vim.current.buffer.append('\n')

    vim.command('setlocal nomodifiable')

except Exception as excp:
    print(excp)

EOF

endfunction

command! -nargs=1 Cards call Cards(<q-args>)
