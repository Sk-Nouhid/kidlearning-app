import { useEffect, useState } from 'react'
import type { FormEvent, ReactNode } from 'react'
import { API_BASE, imageUrl, request } from './api'
import type { Game, LibraryQuestion, MediaAsset, Question, QuestionData, Template } from './api'

type Section = 'Dashboard' | 'Games' | 'Questions' | 'Settings'
type GamePayload = { title: string; description: string }
type QuestionDraft = { prompt: string; type: 'matching' | 'multiple_choice'; pairs: { left: string; right: string }[]; options: string[]; answer: string }

const navItems: { name: Section; icon: string }[] = [
  { name: 'Dashboard', icon: 'grid' }, { name: 'Games', icon: 'book' },
  { name: 'Questions', icon: 'spark' }, { name: 'Settings', icon: 'settings' },
]

function Icon({ name, size = 19 }: { name: string; size?: number }) {
  const paths: Record<string, ReactNode> = {
    grid: <><rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/></>,
    book: <><path d="M4 5.5A2.5 2.5 0 0 1 6.5 3H20v16H6.5A2.5 2.5 0 0 0 4 21z"/><path d="M4 5.5v13A2.5 2.5 0 0 1 6.5 16H20M8 7h7"/></>,
    spark: <><path d="m12 3 1.9 5.8L20 11l-6.1 2.2L12 19l-1.9-5.8L4 11l6.1-2.2z"/><path d="m19 16 .8 2.2L22 19l-2.2.8L19 22l-.8-2.2L16 19l2.2-.8z"/></>,
    settings: <><circle cx="12" cy="12" r="3"/><path d="m19.4 15 .1.1 1.1.9-1.2 2.1-1.4-.5a7.5 7.5 0 0 1-1.5.9l-.2 1.5h-2.4l-.3-1.5a7.5 7.5 0 0 1-1.5-.9l-1.4.5-1.2-2.1 1.1-.9a7 7 0 0 1 0-1.8l-1.1-.9 1.2-2.1 1.4.5a7.5 7.5 0 0 1 1.5-.9l.3-1.5h2.4l.2 1.5a7.5 7.5 0 0 1 1.5.9l1.4-.5 1.2 2.1-1.1.9a7 7 0 0 1 0 1.8Z" transform="translate(-1 -1)"/></>,
    plus: <><path d="M12 5v14M5 12h14"/></>,
    arrow: <><path d="M5 12h14M13 6l6 6-6 6"/></>,
    chevron: <path d="m9 18 6-6-6-6"/>,
    search: <><circle cx="10.8" cy="10.8" r="6.8"/><path d="m16 16 4.5 4.5"/></>,
    close: <><path d="m18 6-12 12M6 6l12 12"/></>,
    trash: <><path d="M4 7h16M10 11v6M14 11v6M5 7l1 14h12l1-14M9 7V4h6v3"/></>,
    edit: <><path d="m4 16.5-.8 4.3 4.3-.8L20 7.5 16.5 4z"/><path d="m14.5 6 3.5 3.5"/></>,
    image: <><rect x="3" y="4" width="18" height="16" rx="3"/><circle cx="8.5" cy="9" r="1.5"/><path d="m21 15-5-5L5 20"/></>,
    eye: <><path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12Z"/><circle cx="12" cy="12" r="2.5"/></>,
    upload: <><path d="M12 16V4m-5 5 5-5 5 5"/><path d="M4 16v4h16v-4"/></>,
    lock: <><rect x="4" y="10" width="16" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/></>,
    logout: <><path d="M10 17l5-5-5-5M15 12H3"/><path d="M12 3h7a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-7"/></>,
    check: <path d="m5 12 4 4L19 6"/>,
    clock: <><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></>,
    dots: <><circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/></>,
    leaf: <><path d="M20 4c-8 0-14 3-14 10a6 6 0 0 0 6 6c7 0 10-8 8-16Z"/><path d="M4 21c2-5 6-8 11-11"/></>,
    question: <><path d="M9.1 9a3 3 0 0 1 5.8 1c0 2-3 3-3 3"/><path d="M12 17h.01"/><circle cx="12" cy="12" r="9"/></>,
  }
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{paths[name] || paths.spark}</svg>
}

function initialDraft(type: QuestionDraft['type'] = 'multiple_choice'): QuestionDraft {
  return { prompt: '', type, pairs: [{ left: '', right: '' }, { left: '', right: '' }], options: ['', '', '', ''], answer: '' }
}

function asQuestionData(draft: QuestionDraft): QuestionData {
  if (draft.type === 'matching') return { type: 'matching', pairs: draft.pairs.map((pair) => ({ left: pair.left.trim(), right: pair.right.trim() })) }
  const options = draft.options.map((option) => option.trim())
  return { type: 'multiple_choice', options, answer: draft.answer.trim() }
}

function fromQuestion(question: Question): QuestionDraft {
  if (question.question_data.type === 'matching') return { ...initialDraft('matching'), prompt: question.prompt, pairs: question.question_data.pairs }
  return { ...initialDraft(), prompt: question.prompt, options: question.question_data.options, answer: question.question_data.answer }
}

function App() {
  // A sessionStorage JWT is still readable by injected JavaScript; it is used here only to match the requested demo session behavior.
  const [token, setToken] = useState<string | null>(() => sessionStorage.getItem('tinytrail_teacher_token'))
  const [loginId, setLoginId] = useState(() => sessionStorage.getItem('tinytrail_teacher_login') || '')
  const [section, setSection] = useState<Section>('Dashboard')
  const [games, setGames] = useState<Game[]>([])
  const [templates, setTemplates] = useState<Template[]>([])
  const [library, setLibrary] = useState<LibraryQuestion[]>([])
  const [media, setMedia] = useState<MediaAsset[]>([])
  const [mediaTab, setMediaTab] = useState<'library' | 'media'>('library')
  const [loading, setLoading] = useState(false)
  const [pageError, setPageError] = useState('')
  const [toast, setToast] = useState('')
  const [modalError, setModalError] = useState('')
  const [loginNotice, setLoginNotice] = useState('')
  const [query, setQuery] = useState('')
  const [statusFilter, setStatusFilter] = useState<'all' | 'draft' | 'published'>('all')
  const [selectedGameId, setSelectedGameId] = useState<number | null>(null)
  const [gameQuestions, setGameQuestions] = useState<Question[]>([])
  const [questionsLoading, setQuestionsLoading] = useState(false)
  const [gameForm, setGameForm] = useState<GamePayload>({ title: '', description: '' })
  const [gameFormOpen, setGameFormOpen] = useState(false)
  const [editingGame, setEditingGame] = useState(false)
  const [templateId, setTemplateId] = useState<number | ''>('')
  const [questionDraft, setQuestionDraft] = useState<QuestionDraft>(initialDraft())
  const [questionFormOpen, setQuestionFormOpen] = useState(false)
  const [editingQuestion, setEditingQuestion] = useState<Question | null>(null)
  const [questionSaving, setQuestionSaving] = useState(false)
  const [loginForm, setLoginForm] = useState({ loginId: '', password: '' })
  const [loginBusy, setLoginBusy] = useState(false)
  const [loginError, setLoginError] = useState('')
  const [passwordForm, setPasswordForm] = useState({ currentPassword: '', newPassword: '', confirmPassword: '' })
  const [passwordBusy, setPasswordBusy] = useState(false)
  const [uploadBusy, setUploadBusy] = useState(false)

  function notify(message: string) {
    setToast(message)
    window.setTimeout(() => setToast(''), 3200)
  }

  async function loadWorkspace() {
    if (!token) return
    setLoading(true)
    setPageError('')
    const [gameResult, templateResult, questionResult] = await Promise.allSettled([
      request<{ games: Game[] }>('/api/games', token),
      request<{ templates: Template[] }>('/api/templates', token),
      request<{ questions: LibraryQuestion[] }>('/api/questions', token),
    ])
    if (gameResult.status === 'fulfilled') setGames(gameResult.value.games || [])
    else setPageError(gameResult.reason instanceof Error ? gameResult.reason.message : 'Could not load games')
    if (templateResult.status === 'fulfilled') setTemplates(templateResult.value.templates || [])
    if (questionResult.status === 'fulfilled') setLibrary(questionResult.value.questions || [])
    const secondaryErrors = [templateResult, questionResult]
      .filter((result): result is PromiseRejectedResult => result.status === 'rejected')
      .map((result) => result.reason instanceof Error ? result.reason.message : 'A workspace section could not be loaded')
    if (secondaryErrors.length && gameResult.status === 'fulfilled') setPageError(secondaryErrors.join(' '))
    setLoading(false)
  }

  useEffect(() => { void loadWorkspace() }, [token])

  useEffect(() => {
    if (!token || selectedGameId === null) return
    let active = true
    setQuestionsLoading(true)
    request<{ questions: Question[] }>(`/api/games/${selectedGameId}/questions`, token)
      .then((result) => { if (active) setGameQuestions(result.questions || []) })
      .catch((error: Error) => { if (active) setPageError(error.message) })
      .finally(() => { if (active) setQuestionsLoading(false) })
    return () => { active = false }
  }, [token, selectedGameId])

  useEffect(() => {
    if (!token || section !== 'Questions' || mediaTab !== 'media') return
    request<{ images: MediaAsset[] }>('/api/media', token)
      .then((result) => setMedia(result.images || []))
      .catch((error: Error) => setPageError(error.message))
  }, [token, section, mediaTab])

  useEffect(() => {
    const handleUnauthorized = () => {
      sessionStorage.removeItem('tinytrail_teacher_token')
      sessionStorage.removeItem('tinytrail_teacher_login')
      setToken(null)
      setLoginId('')
      setGames([])
      setSelectedGameId(null)
      setGameQuestions([])
      setLoginNotice('Your session expired. Please sign in again.')
    }
    window.addEventListener('tinytrail:unauthorized', handleUnauthorized)
    return () => window.removeEventListener('tinytrail:unauthorized', handleUnauthorized)
  }, [])

  async function signIn(event: FormEvent) {
    event.preventDefault()
    setLoginBusy(true)
    setLoginError('')
    setLoginNotice('')
    try {
      const result = await request<{ token: string; teacher: { loginId: string } }>('/api/teacher-auth/login', null, {
        method: 'POST', body: JSON.stringify(loginForm),
      })
      // The short-lived UI session is kept only for this browser tab/session, never as a persistent login.
      sessionStorage.setItem('tinytrail_teacher_token', result.token)
      sessionStorage.setItem('tinytrail_teacher_login', result.teacher.loginId)
      setToken(result.token)
      setLoginId(result.teacher.loginId)
      setSection('Dashboard')
    } catch (error) { setLoginError(error instanceof Error ? error.message : 'Unable to sign in') }
    finally { setLoginBusy(false) }
  }

  function signOut() {
    sessionStorage.removeItem('tinytrail_teacher_token')
    sessionStorage.removeItem('tinytrail_teacher_login')
    setToken(null); setLoginId(''); setGames([]); setSelectedGameId(null)
  }

  function openNewGame() {
    setGameForm({ title: '', description: '' }); setTemplateId(''); setEditingGame(false); setModalError(''); setGameFormOpen(true)
  }

  function openGameEdit(game: Game) {
    setGameForm({ title: game.title, description: game.description || '' }); setEditingGame(true); setModalError(''); setGameFormOpen(true)
  }

  async function saveGame(event: FormEvent) {
    event.preventDefault()
    try {
      if (editingGame && selectedGameId !== null) {
        const result = await request<{ game: Game }>(`/api/games/${selectedGameId}`, token, { method: 'PUT', body: JSON.stringify(gameForm) })
        setGames((all) => all.map((game) => game.id === selectedGameId ? { ...game, ...result.game } : game))
        notify('Draft details saved')
      } else {
        const result = await request<{ game: Game }>('/api/games', token, { method: 'POST', body: JSON.stringify({ ...gameForm, template_id: Number(templateId) }) })
        const createdGame = { ...result.game, template_name: templates.find((template) => template.id === Number(templateId))?.name || '' }
        setGames((all) => [createdGame, ...all])
        setSelectedGameId(result.game.id)
        setSection('Games')
        notify('Your new draft is ready')
      }
      setGameFormOpen(false)
    } catch (error) { setModalError(error instanceof Error ? error.message : 'Could not save game') }
  }

  async function deleteGame(game: Game) {
    if (!window.confirm(`Delete “${game.title}”? This removes the draft and its game links.`)) return
    try {
      await request(`/api/games/${game.id}`, token, { method: 'DELETE' })
      setGames((all) => all.filter((item) => item.id !== game.id))
      setSelectedGameId(null); setGameQuestions([]); notify('Draft deleted')
    } catch (error) { setPageError(error instanceof Error ? error.message : 'Could not delete game') }
  }

  async function publishGame(game: Game) {
    try {
      await request(`/api/games/${game.id}/publish`, token, { method: 'PATCH' })
      setGames((all) => all.map((item) => item.id === game.id ? { ...item, status: 'published' } : item))
      notify('Game published for learners')
    } catch (error) { setPageError(error instanceof Error ? error.message : 'Could not publish game') }
  }

  function openQuestionForm(question?: Question) {
    setEditingQuestion(question || null)
    setQuestionDraft(question ? fromQuestion(question) : initialDraft())
    setModalError('')
    setQuestionFormOpen(true)
  }

  async function saveQuestion(event: FormEvent) {
    event.preventDefault()
    setQuestionSaving(true)
    const body = { prompt: questionDraft.prompt.trim(), question_data: asQuestionData(questionDraft) }
    try {
      if (editingQuestion && selectedGameId !== null) {
        await request(`/api/games/${selectedGameId}/questions/${editingQuestion.id}`, token, { method: 'PUT', body: JSON.stringify({ ...body, sort_order: editingQuestion.sort_order }) })
        await reloadGameQuestions()
        notify('Question updated in this draft')
      } else if (selectedGameId !== null && section === 'Games') {
        await request(`/api/games/${selectedGameId}/questions`, token, { method: 'POST', body: JSON.stringify(body) })
        await reloadGameQuestions()
        notify('Question added to draft')
      } else {
        const result = await request<{ question: LibraryQuestion }>('/api/questions', token, { method: 'POST', body: JSON.stringify(body) })
        setLibrary((all) => [result.question, ...all.filter((item) => item.id !== result.question.id)])
        notify('Question added to your library')
      }
      setQuestionFormOpen(false)
    } catch (error) { setModalError(error instanceof Error ? error.message : 'Could not save question') }
    finally { setQuestionSaving(false) }
  }

  async function reloadGameQuestions() {
    if (selectedGameId === null) return
    const result = await request<{ questions: Question[] }>(`/api/games/${selectedGameId}/questions`, token)
    setGameQuestions(result.questions || [])
  }

  async function removeGameQuestion(question: Question) {
    if (selectedGameId === null || !window.confirm('Remove this question from the draft? The library question will be kept.')) return
    try {
      await request(`/api/games/${selectedGameId}/questions/${question.id}`, token, { method: 'DELETE' })
      setGameQuestions((all) => all.filter((item) => item.id !== question.id)); notify('Question removed from draft')
    } catch (error) { setPageError(error instanceof Error ? error.message : 'Could not remove question') }
  }

  async function reuseQuestion(question: LibraryQuestion) {
    if (selectedGameId === null) return
    try {
      await request(`/api/questions/games/${selectedGameId}/questions/reuse`, token, {
        method: 'POST', body: JSON.stringify({ question_id: question.id }),
      })
      await reloadGameQuestions()
      notify('Question added from your library')
    } catch (error) { setPageError(error instanceof Error ? error.message : 'Could not add library question') }
  }

  async function uploadImage(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = event.currentTarget
    const fileInput = form.elements.namedItem('image') as HTMLInputElement
    const file = fileInput.files?.[0]
    if (!file) return
    if (file.size > 5 * 1024 * 1024) { setPageError('Choose an image smaller than 5 MB.'); return }
    setUploadBusy(true)
    const data = new FormData(); data.append('image', file)
    try {
      await request('/api/media/upload', token, { method: 'POST', body: data })
      const result = await request<{ images: MediaAsset[] }>('/api/media', token)
      setMedia(result.images || []); fileInput.value = ''; notify('Image uploaded to your media library')
    } catch (error) { setPageError(error instanceof Error ? error.message : 'Could not upload image') }
    finally { setUploadBusy(false) }
  }

  async function changePassword(event: FormEvent) {
    event.preventDefault()
    if (passwordForm.newPassword !== passwordForm.confirmPassword) { setPageError('Your new passwords do not match.'); return }
    if (passwordForm.newPassword.length < 8) { setPageError('Choose a new password with at least 8 characters.'); return }
    setPasswordBusy(true)
    try {
      await request('/api/teacher-auth/change-password', token, { method: 'POST', body: JSON.stringify({ currentPassword: passwordForm.currentPassword, newPassword: passwordForm.newPassword }) })
      setPasswordForm({ currentPassword: '', newPassword: '', confirmPassword: '' })
      setLoginNotice('Your password was changed. Sign in again with your new password.')
      signOut()
    } catch (error) { setPageError(error instanceof Error ? error.message : 'Could not change password') }
    finally { setPasswordBusy(false) }
  }

  if (!token) return <LoginScreen form={loginForm} setForm={setLoginForm} error={loginError} notice={loginNotice} busy={loginBusy} onSubmit={signIn} />

  const selectedGame = games.find((game) => game.id === selectedGameId) || null
  const visibleGames = games.filter((game) => (statusFilter === 'all' || game.status === statusFilter) && `${game.title} ${game.template_name}`.toLowerCase().includes(query.toLowerCase()))
  const visibleQuestions = library.filter((question) => question.prompt.toLowerCase().includes(query.toLowerCase()))
  const draftCount = games.filter((game) => game.status === 'draft').length
  const publishedCount = games.filter((game) => game.status === 'published').length

  return <div className="app-shell">
    <aside className="sidebar">
      <a href="#dashboard" className="brand" onClick={(event) => { event.preventDefault(); setSection('Dashboard'); setSelectedGameId(null) }}>
        <span className="brand-mark"><Icon name="leaf" size={23} /></span><span className="brand-copy"><b>tinytrail</b><small>TEACHER STUDIO</small></span>
      </a>
      <div className="workspace-label">WORKSPACE</div>
      <nav className="main-nav" aria-label="Main navigation">
        {navItems.map((item) => <button className={`nav-link ${section === item.name ? 'active' : ''}`} key={item.name} onClick={() => { setSection(item.name); setSelectedGameId(null); setPageError('') }}><Icon name={item.icon} /><span>{item.name}</span>{item.name === 'Games' && <span className="nav-count">{games.length}</span>}</button>)}
      </nav>
      <div className="sidebar-bottom">
        <div className="sidebar-note"><span className="note-flower">✳</span><b>Little steps,<br />big discoveries.</b><small>Make room for wonder.</small></div>
        <div className="profile-row"><div className="avatar">{(loginId[0] || 'T').toUpperCase()}</div><div className="profile-meta"><b>{loginId || 'Teacher'}</b><small>Teacher account</small></div><button className="icon-button signout" aria-label="Sign out" title="Sign out" onClick={signOut}><Icon name="logout" size={17} /></button></div>
      </div>
    </aside>

    <main className="main-area">
      <header className="topbar"><div className="breadcrumb"><span>Teacher studio</span><Icon name="chevron" size={14} /><b>{section}</b>{section === 'Games' && selectedGame && <><Icon name="chevron" size={14} /><b>{selectedGame.title}</b></>}</div><div className="topbar-right"><span className="api-status"><i /> Workspace connected</span><span className="top-avatar">{(loginId[0] || 'T').toUpperCase()}</span></div></header>
      <div className="page-wrap">
        {pageError && <div className="alert error-alert" role="alert"><span>{pageError}</span><button aria-label="Dismiss error" onClick={() => setPageError('')}><Icon name="close" size={16} /></button></div>}
        {section === 'Dashboard' && <Dashboard games={games} draftCount={draftCount} publishedCount={publishedCount} loading={loading} error={pageError} onNavigate={setSection} onOpenGame={(id) => { setSelectedGameId(id); setSection('Games') }} onCreate={openNewGame} />}
        {section === 'Games' && <GamesPage games={visibleGames} allCount={games.length} filter={statusFilter} setFilter={setStatusFilter} query={query} setQuery={setQuery} loading={loading} selectedGame={selectedGame} questions={gameQuestions} questionsLoading={questionsLoading} onCreate={openNewGame} onSelect={(id) => { setPageError(''); setSelectedGameId(id) }} onBack={() => setSelectedGameId(null)} onEdit={openGameEdit} onDelete={deleteGame} onPublish={publishGame} onAddQuestion={() => openQuestionForm()} onEditQuestion={openQuestionForm} onDeleteQuestion={removeGameQuestion} library={library} onReuseQuestion={reuseQuestion} />}
        {section === 'Questions' && <QuestionsPage library={visibleQuestions} total={library.length} query={query} setQuery={setQuery} mediaTab={mediaTab} setMediaTab={setMediaTab} media={media} onCreate={() => openQuestionForm()} onUpload={uploadImage} uploadBusy={uploadBusy} />}
        {section === 'Settings' && <SettingsPage loginId={loginId} password={passwordForm} setPassword={setPasswordForm} busy={passwordBusy} onSubmit={changePassword} apiBase={API_BASE} />}
      </div>
    </main>

    {gameFormOpen && <Modal title={editingGame ? 'Edit draft details' : 'Start a new game'} subtitle={editingGame ? 'Give your draft a fresh name or description.' : 'Pick a format to begin your next little adventure.'} error={modalError} onClose={() => setGameFormOpen(false)}>
      <form className="form-stack" onSubmit={saveGame}>
        {!editingGame && <div className="template-picks">
          {templates.filter((template) => ['matching', 'multiple_choice'].includes(template.template_key)).map((template, index) => <button type="button" className={`template-card ${templateId === template.id ? 'chosen' : ''}`} key={template.id} onClick={() => setTemplateId(template.id)}><span className={`template-symbol tint-${index % 2}`}>{template.template_key === 'matching' ? '↔' : 'A'}</span><b>{template.name}</b><small>{template.description || (template.template_key === 'matching' ? 'Connect pairs that belong together' : 'Choose the best answer')}</small><span className="select-dot">{templateId === template.id && <Icon name="check" size={13} />}</span></button>)}
          {templates.filter((template) => ['matching', 'multiple_choice'].includes(template.template_key)).length === 0 && <p className="muted">No matching or multiple-choice templates are available right now.</p>}
        </div>}
        <label className="field-label">Game title<input autoFocus required maxLength={150} placeholder="e.g. A walk in the woods" value={gameForm.title} onChange={(event) => setGameForm({ ...gameForm, title: event.target.value })} /></label>
        <label className="field-label">A little description <span className="optional">Optional</span><textarea rows={3} maxLength={5000} placeholder="What will your learners discover?" value={gameForm.description} onChange={(event) => setGameForm({ ...gameForm, description: event.target.value })} /></label>
        <div className="modal-actions"><button type="button" className="button quiet" onClick={() => setGameFormOpen(false)}>Cancel</button><button className="button primary" disabled={!editingGame && (templateId === '' || templates.length === 0)}>{editingGame ? 'Save changes' : 'Create draft'} <Icon name="arrow" size={16} /></button></div>
      </form>
    </Modal>}

    {questionFormOpen && <QuestionModal draft={questionDraft} setDraft={setQuestionDraft} editing={!!editingQuestion} busy={questionSaving} error={modalError} onClose={() => setQuestionFormOpen(false)} onSubmit={saveQuestion} />}
    {toast && <div className="toast" role="status"><span className="toast-check"><Icon name="check" size={15} /></span>{toast}</div>}
  </div>
}

function PasswordField({ value, onChange, autoComplete = 'current-password', placeholder, minLength }: { value: string; onChange: (value: string) => void; autoComplete?: string; placeholder?: string; minLength?: number }) {
  const [visible, setVisible] = useState(false)
  return <div className="password-field">
    <input type={visible ? 'text' : 'password'} autoComplete={autoComplete} required minLength={minLength} value={value} placeholder={placeholder} onChange={(event) => onChange(event.target.value)} />
    <button type="button" className="password-toggle" onClick={() => setVisible(!visible)} aria-label={visible ? 'Hide password' : 'Show password'}>{visible ? 'Hide' : 'Show'}</button>
  </div>
}

function LoginScreen({ form, setForm, error, notice, busy, onSubmit }: { form: { loginId: string; password: string }; setForm: (value: { loginId: string; password: string }) => void; error: string; notice: string; busy: boolean; onSubmit: (event: FormEvent) => void }) {
  return <div className="login-screen"><div className="login-art"><div className="login-brand"><span className="brand-mark"><Icon name="leaf" size={23} /></span><b>tinytrail</b></div><div className="art-sun" /><div className="art-hill hill-back" /><div className="art-hill hill-front" /><div className="art-flower flower-one">✳</div><div className="art-flower flower-two">✿</div><div className="art-message"><span>Curiosity lives here</span><h1>A little space<br />for big ideas.</h1><p>Your classroom's next great adventure starts with you.</p></div><div className="art-foot">A gentle place to make learning playful <span>✦</span></div></div><div className="login-panel"><div className="login-top"><span className="mobile-brand"><span className="brand-mark"><Icon name="leaf" size={21} /></span><b>tinytrail</b></span><span>TEACHER PORTAL</span></div><div className="login-content"><span className="eyebrow">WELCOME BACK</span><h2>Let’s make<br />something wonderful.</h2><p>Sign in to pick up where your class left off.</p>{notice && <div className="success-alert">{notice}</div>}{error && <div className="alert error-alert">{error}</div>}<form className="form-stack login-form" onSubmit={onSubmit}><label className="field-label">Teacher ID<input autoFocus autoComplete="username" required value={form.loginId} placeholder="Your teacher ID" onChange={(event) => setForm({ ...form, loginId: event.target.value })} /></label><label className="field-label">Password<PasswordField value={form.password} placeholder="Your password" onChange={(value) => setForm({ ...form, password: value })} /></label><button className="button primary login-button" disabled={busy}>{busy ? 'Finding your studio…' : 'Step inside'} <Icon name="arrow" size={17} /></button></form><div className="login-security"><Icon name="lock" size={15} /><span>Your classroom space is just for you.</span></div></div><div className="login-footer">Made for the magic in everyday learning <span>✳</span></div></div></div>
}

function Dashboard({ games, draftCount, publishedCount, loading, error, onNavigate, onOpenGame, onCreate }: { games: Game[]; draftCount: number; publishedCount: number; loading: boolean; error: string; onNavigate: (section: Section) => void; onOpenGame: (id: number) => void; onCreate: () => void }) {
  const recent = games.slice(0, 4)
  return <div className="page-content dashboard-page"><div className="welcome-row"><div><span className="eyebrow">YOUR LITTLE CORNER OF THE WORLD</span><h1>Good things grow here<span className="heading-period">.</span></h1><p>Welcome back. What will your learners discover today?</p></div><button className="button primary" onClick={onCreate}><Icon name="plus" size={17} /> New game</button></div>
    <section className="hero-card"><div className="hero-copy"><span className="hero-kicker"><span>✳</span> YOUR STUDIO, YOUR STORY</span><h2>Every great adventure<br />starts with a question.</h2><p>Build a playful game, add a few curious questions,<br className="desktop-break" /> and let your learners take the lead.</p><button className="button hero-button" onClick={onCreate}>Create your first game <Icon name="arrow" size={16} /></button></div><div className="hero-illustration" aria-hidden="true"><div className="orbit orbit-one" /><div className="orbit orbit-two" /><div className="sun-disc">✦</div><div className="book-shape"><div /><i /><b>?</b></div><span className="float-star star-a">✦</span><span className="float-star star-b">✳</span><span className="float-dot dot-a" /><span className="float-dot dot-b" /></div><span className="hero-number">01 — 04</span></section>
    <div className="stats-row"><StatCard label="All games" value={loading ? '—' : games.length} caption="Your learning collection" icon="book" tone="lavender" /><StatCard label="In the making" value={loading ? '—' : draftCount} caption="Drafts in progress" icon="clock" tone="peach" /><StatCard label="Out in the world" value={loading ? '—' : publishedCount} caption="Ready for learners" icon="spark" tone="mint" /></div>
    <div className="dashboard-lower"><section className="panel recent-panel"><div className="section-heading"><div><span className="eyebrow">FRESH FROM YOUR STUDIO</span><h2>Recently updated</h2></div><button className="text-button" onClick={() => onNavigate('Games')}>See all games <Icon name="arrow" size={15} /></button></div>{loading ? <div className="loading-state"><span className="spinner" />Gathering your games…</div> : recent.length ? <div className="recent-list">{recent.map((game, index) => <button className="recent-item" key={game.id} onClick={() => onOpenGame(game.id)}><span className={`game-art art-${index % 4}`}>{index % 2 === 0 ? <Icon name="spark" size={20} /> : <Icon name="book" size={20} />}</span><span className="recent-info"><b>{game.title}</b><small>{game.template_name || 'Learning game'} · Updated {formatDate(game.updated_at)}</small></span><StatusPill status={game.status} /><Icon name="chevron" size={17} /></button>)}</div> : <EmptyState icon="book" title={error ? 'Your games could not load' : 'Your story starts here'} detail={error ? 'Check your connection and try again.' : 'Create your first game and make a little learning magic.'} action={!error ? <button className="text-button" onClick={onCreate}>Make a game <Icon name="arrow" size={15} /></button> : undefined} />}</section><aside className="tip-card"><span className="tip-icon">✳</span><span className="eyebrow">A TINY TRAIL TIP</span><h3>Small questions<br />open big doors.</h3><p>Try mixing matching games and multiple choice to invite different kinds of thinking.</p><button className="text-button" onClick={() => onNavigate('Questions')}>Explore your questions <Icon name="arrow" size={15} /></button><div className="tip-doodle">⌁</div></aside></div>
  </div>
}

function StatCard({ label, value, caption, icon, tone }: { label: string; value: string | number; caption: string; icon: string; tone: string }) {
  return <div className="stat-card"><span className={`stat-icon ${tone}`}><Icon name={icon} size={19} /></span><div className="stat-copy"><span>{label}</span><b>{value}</b><small>{caption}</small></div><span className="stat-spark">✳</span></div>
}

function GamesPage({ games, allCount, filter, setFilter, query, setQuery, loading, selectedGame, questions, questionsLoading, onCreate, onSelect, onBack, onEdit, onDelete, onPublish, onAddQuestion, onEditQuestion, onDeleteQuestion, library, onReuseQuestion }: { games: Game[]; allCount: number; filter: 'all' | 'draft' | 'published'; setFilter: (value: 'all' | 'draft' | 'published') => void; query: string; setQuery: (value: string) => void; loading: boolean; selectedGame: Game | null; questions: Question[]; questionsLoading: boolean; onCreate: () => void; onSelect: (id: number) => void; onBack: () => void; onEdit: (game: Game) => void; onDelete: (game: Game) => void; onPublish: (game: Game) => void; onAddQuestion: () => void; onEditQuestion: (question: Question) => void; onDeleteQuestion: (question: Question) => void; library: LibraryQuestion[]; onReuseQuestion: (question: LibraryQuestion) => void }) {
  if (selectedGame) return <GameDetail game={selectedGame} questions={questions} loading={questionsLoading} onBack={onBack} onEdit={() => onEdit(selectedGame)} onDelete={() => onDelete(selectedGame)} onPublish={() => onPublish(selectedGame)} onAddQuestion={onAddQuestion} onEditQuestion={onEditQuestion} onDeleteQuestion={onDeleteQuestion} library={library} onReuseQuestion={onReuseQuestion} />
  return <div className="page-content"><div className="page-title-row"><div><span className="eyebrow">MAKE, SHAPE, SHARE</span><h1>Your games</h1><p>A home for every learning adventure you create.</p></div><button className="button primary" onClick={onCreate}><Icon name="plus" size={17} /> New game</button></div><div className="list-toolbar"><div className="filter-tabs"><button className={filter === 'all' ? 'selected' : ''} onClick={() => setFilter('all')}>All <span>{allCount}</span></button><button className={filter === 'draft' ? 'selected' : ''} onClick={() => setFilter('draft')}>Drafts</button><button className={filter === 'published' ? 'selected' : ''} onClick={() => setFilter('published')}>Published</button></div><label className="search-box"><Icon name="search" size={17} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Find a game" /><kbd>⌘ K</kbd></label></div>{loading ? <div className="panel loading-state"><span className="spinner" />Loading your games…</div> : games.length ? <div className="game-grid">{games.map((game, index) => <GameCard key={game.id} game={game} index={index} onClick={() => onSelect(game.id)} />)}</div> : <div className="panel"><EmptyState icon="book" title={allCount ? 'No games match that search' : 'Nothing here just yet'} detail={allCount ? 'Try another title or status filter.' : 'Your first game is only a few clicks away.'} action={!allCount ? <button className="button primary" onClick={onCreate}><Icon name="plus" size={16} /> Create a game</button> : undefined} /></div>}</div>
}

function GameCard({ game, index, onClick }: { game: Game; index: number; onClick: () => void }) {
  return <button className="game-card" onClick={onClick}><div className={`card-art card-art-${index % 4}`}><span className="card-art-glyph">{['✳', '↗', '✿', '⌁'][index % 4]}</span><span className="card-art-label">{game.template_name || 'Learning game'}</span></div><div className="game-card-content"><div className="game-card-heading"><h3>{game.title}</h3><Icon name="dots" size={20} /></div><p>{game.description || 'A little learning adventure, ready to take shape.'}</p><div className="game-card-bottom"><StatusPill status={game.status} /><small>Updated {formatDate(game.updated_at)}</small><Icon name="arrow" size={16} /></div></div></button>
}

function GameDetail({ game, questions, loading, onBack, onEdit, onDelete, onPublish, onAddQuestion, onEditQuestion, onDeleteQuestion, library, onReuseQuestion }: { game: Game; questions: Question[]; loading: boolean; onBack: () => void; onEdit: () => void; onDelete: () => void; onPublish: () => void; onAddQuestion: () => void; onEditQuestion: (question: Question) => void; onDeleteQuestion: (question: Question) => void; library: LibraryQuestion[]; onReuseQuestion: (question: LibraryQuestion) => void }) {
  const canPublish = game.status === 'draft' && questions.length >= 5
  const [previewOpen, setPreviewOpen] = useState(false)
  const [libraryOpen, setLibraryOpen] = useState(false)
  return <><div className="page-content game-detail-page"><button className="back-link" onClick={onBack}><span>←</span> All games</button><div className={`detail-banner detail-${game.status}`}><div className="detail-ornament">{game.status === 'published' ? '✦' : '✳'}</div><div className="detail-head"><span className="eyebrow">{game.template_name || 'LEARNING GAME'}</span><h1>{game.title}</h1><p>{game.description || 'A little learning adventure, ready to take shape.'}</p></div><div className="detail-actions"><StatusPill status={game.status} />{questions.length > 0 && <button className="button soft" onClick={() => setPreviewOpen(true)}><Icon name="eye" size={15} /> Preview</button>}{game.status === 'draft' && <><button className="button soft" onClick={onEdit}><Icon name="edit" size={15} /> Edit details</button><button className="button danger-soft" onClick={onDelete}><Icon name="trash" size={15} /></button></>}</div></div>
    <div className="detail-columns"><section className="panel questions-panel"><div className="section-heading"><div><span className="eyebrow">THE LEARNING PATH</span><h2>Questions <span className="count-bubble">{loading ? '…' : questions.length}</span></h2></div>{game.status === 'draft' && <div className="heading-actions"><button className="button outline small" onClick={() => setLibraryOpen(true)}><Icon name="book" size={15} /> Add from library</button><button className="button outline small" onClick={onAddQuestion}><Icon name="plus" size={15} /> Add question</button></div>}</div>{game.status === 'draft' && <div className={`publish-progress ${canPublish ? 'ready' : ''}`}><div className="progress-top"><span>{canPublish ? 'Your game is ready to publish' : 'A few more questions to go'}</span><b>{Math.min(questions.length, 5)} <i>/ 5</i></b></div><div className="progress-track"><span style={{ width: `${Math.min(questions.length / 5, 1) * 100}%` }} /></div><small>{canPublish ? 'You have the minimum five questions. You can always add more.' : `${5 - questions.length} more ${5 - questions.length === 1 ? 'question' : 'questions'} needed before this game can go live.`}</small></div>}
      {loading ? <div className="loading-state"><span className="spinner" />Loading questions…</div> : questions.length ? <div className="question-list">{questions.map((question) => <div className="question-row" key={question.id}><span className="question-number">{String(question.sort_order).padStart(2, '0')}</span><div className="question-row-copy"><b>{question.prompt}</b><small><span className={`type-dot ${question.question_data.type}`} />{question.question_data.type === 'matching' ? 'Matching' : 'Multiple choice'}</small></div>{game.status === 'draft' && <div className="row-actions"><button className="icon-button" title="Edit question" aria-label="Edit question" onClick={() => onEditQuestion(question)}><Icon name="edit" size={16} /></button><button className="icon-button remove" title="Remove question" aria-label="Remove question" onClick={() => onDeleteQuestion(question)}><Icon name="trash" size={16} /></button></div>}</div>)}</div> : <EmptyState icon="question" title="A path with no questions yet" detail="Add a question to start shaping this learning adventure." action={game.status === 'draft' ? <button className="text-button" onClick={onAddQuestion}>Add the first question <Icon name="arrow" size={15} /></button> : undefined} />}
    </section><aside className="detail-aside"><section className="panel publish-panel"><span className={`publish-icon ${game.status}`}><Icon name={game.status === 'published' ? 'check' : 'spark'} size={19} /></span><h3>{game.status === 'published' ? 'Out in the world' : 'Ready when you are'}</h3><p>{game.status === 'published' ? 'Learners can now find this game in their collection.' : 'A published game is ready for curious minds to explore.'}</p>{game.status === 'draft' ? <button className="button primary full-button" disabled={!canPublish} onClick={onPublish}>Publish game <Icon name="arrow" size={16} /></button> : <div className="published-note"><Icon name="check" size={15} /> Published {formatDate(game.updated_at)}</div>}{game.status === 'draft' && !canPublish && <small className="disabled-reason">Add 5 questions to unlock publishing.</small>}</section><section className="panel details-panel"><span className="eyebrow">AT A GLANCE</span><div className="detail-stat"><span>Format</span><b>{game.template_name || '—'}</b></div><div className="detail-stat"><span>Created</span><b>{formatDate(game.created_at)}</b></div><div className="detail-stat"><span>Last updated</span><b>{formatDate(game.updated_at)}</b></div></section></aside></div></div>{previewOpen && <GamePreview game={game} questions={questions} onClose={() => setPreviewOpen(false)} />}{libraryOpen && <LibraryPicker library={library} onClose={() => setLibraryOpen(false)} onPick={(question) => { onReuseQuestion(question); setLibraryOpen(false) }} />}</>
}

function GamePreview({ game, questions, onClose }: { game: Game; questions: Question[]; onClose: () => void }) {
  const [index, setIndex] = useState(0)
  const question = questions[Math.min(index, questions.length - 1)]
  const data = question?.question_data
  return <Modal title={`Preview: ${game.title}`} subtitle="A quick look at what learners will see." onClose={onClose} wide>
    {!question || !data ? <p className="muted">Add a question to preview this game.</p> : <div className="game-preview">
      <div className="preview-progress">Question {index + 1} of {questions.length}</div>
      <h3>{question.prompt}</h3>
      {data.type === 'matching'
        ? <div className="preview-pairs">{data.pairs.map((pair, pairIndex) => <div className="preview-pair" key={pairIndex}><span>{pair.left}</span><span>{pair.right}</span></div>)}</div>
        : <div className="preview-options">{data.options.map((option, optionIndex) => <div className={`preview-option ${option === data.answer ? 'correct' : ''}`} key={optionIndex}><span className="preview-letter">{String.fromCharCode(65 + optionIndex)}</span>{option}{option === data.answer && <Icon name="check" size={14} />}</div>)}</div>}
      <div className="preview-nav"><button className="button quiet" disabled={index === 0} onClick={() => setIndex(index - 1)}>Previous</button><span>{index + 1} / {questions.length}</span><button className="button quiet" disabled={index >= questions.length - 1} onClick={() => setIndex(index + 1)}>Next</button></div>
    </div>}
  </Modal>
}

function LibraryPicker({ library, onClose, onPick }: { library: LibraryQuestion[]; onClose: () => void; onPick: (question: LibraryQuestion) => void }) {
  return <Modal title="Add from your library" subtitle="Reuse a saved prompt in this game." onClose={onClose}>
    {library.length ? <div className="library-picker">{library.map((question) => <button type="button" className="library-pick" key={question.id} onClick={() => onPick(question)}><span className="type-chip">{question.question_data.type === 'matching' ? 'Matching' : 'Multiple choice'}</span><b>{question.prompt}</b><small>{question.question_data.type === 'matching' ? `${question.question_data.pairs.length} matching pairs` : `${question.question_data.options.length} answer choices`}</small></button>)}</div> : <p className="muted">Your question library is empty. Create a question in the Questions section first.</p>}
  </Modal>
}

function QuestionsPage({ library, total, query, setQuery, mediaTab, setMediaTab, media, onCreate, onUpload, uploadBusy }: { library: LibraryQuestion[]; total: number; query: string; setQuery: (value: string) => void; mediaTab: 'library' | 'media'; setMediaTab: (value: 'library' | 'media') => void; media: MediaAsset[]; onCreate: () => void; onUpload: (event: FormEvent<HTMLFormElement>) => void; uploadBusy: boolean }) {
  return <div className="page-content"><div className="page-title-row"><div><span className="eyebrow">YOUR TEACHING TOOLKIT</span><h1>Questions & media</h1><p>Keep your thoughtful prompts and bright ideas close at hand.</p></div></div><div className="subnav-tabs"><button className={mediaTab === 'library' ? 'active' : ''} onClick={() => setMediaTab('library')}><Icon name="question" size={16} /> Question library <span>{total}</span></button><button className={mediaTab === 'media' ? 'active' : ''} onClick={() => setMediaTab('media')}><Icon name="image" size={16} /> Media shelf</button></div>{mediaTab === 'library' ? <><div className="library-toolbar"><div className="library-intro"><h2>Prompts to keep</h2><p>Reusable questions you've made for your games.</p></div><div className="library-actions"><label className="search-box"><Icon name="search" size={17} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Find a question" /></label><button className="button primary" onClick={onCreate}><Icon name="plus" size={16} /> New question</button></div></div>{library.length ? <div className="library-grid">{library.map((question, index) => <article className="library-card" key={question.id}><div className={`library-card-top library-tone-${index % 4}`}><span className="prompt-quote">“</span><span className="type-chip">{question.question_data.type === 'matching' ? 'Matching' : 'Multiple choice'}</span></div><h3>{question.prompt}</h3><div className="library-card-footer"><span>{question.question_data.type === 'matching' ? `${question.question_data.pairs.length} matching pairs` : `${question.question_data.options.length} answer choices`}</span><small>{question.updated_at ? `Added ${formatDate(question.updated_at)}` : 'Reusable prompt'}</small></div></article>)}</div> : <div className="panel"><EmptyState icon="question" title="No prompts found" detail={total ? 'Try a different search.' : 'Create a reusable question to start your library.'} action={!total ? <button className="button primary" onClick={onCreate}><Icon name="plus" size={16} /> New question</button> : undefined} /></div>}</> : <div className="media-layout"><section className="panel upload-panel"><div className="upload-heading"><span className="upload-icon"><Icon name="image" size={20} /></span><div><h2>A little visual sparkle</h2><p>Add an image to use as inspiration in your activities.</p></div></div><form onSubmit={onUpload}><label className="dropzone"><input name="image" type="file" accept="image/jpeg,image/png,image/webp,image/gif" required /><span className="upload-circle"><Icon name="upload" size={19} /></span><b>Choose an image to upload</b><small>JPG, PNG, WEBP or GIF · up to 5 MB</small><span className="button outline small">Browse files</span></label><button className="button primary upload-submit" disabled={uploadBusy}>{uploadBusy ? 'Uploading…' : 'Upload image'} <Icon name="arrow" size={15} /></button></form></section><section className="panel media-panel"><div className="section-heading"><div><span className="eyebrow">YOUR UPLOADS</span><h2>Media shelf</h2></div><span className="media-count">{media.length} {media.length === 1 ? 'image' : 'images'}</span></div>{media.length ? <div className="media-grid">{media.map((asset) => <a className="media-item" href={imageUrl(asset.url)} target="_blank" rel="noreferrer" key={asset.id}><img src={imageUrl(asset.url)} alt={asset.original_name} /><span>{asset.original_name}</span></a>)}</div> : <EmptyState icon="image" title="A fresh, empty shelf" detail="Images you upload will appear here." />}</section></div>}</div>
}

function SettingsPage({ loginId, password, setPassword, busy, onSubmit, apiBase }: { loginId: string; password: { currentPassword: string; newPassword: string; confirmPassword: string }; setPassword: (value: { currentPassword: string; newPassword: string; confirmPassword: string }) => void; busy: boolean; onSubmit: (event: FormEvent) => void; apiBase: string }) {
  return <div className="page-content settings-page"><div className="page-title-row"><div><span className="eyebrow">YOUR SPACE, YOUR WAY</span><h1>Settings</h1><p>Manage your teacher account and studio connection.</p></div></div><div className="settings-grid"><section className="panel settings-card"><div className="settings-card-heading"><span className="settings-icon account"><Icon name="leaf" size={19} /></span><div><h2>Your account</h2><p>The teacher behind the trail.</p></div></div><div className="account-summary"><div className="large-avatar">{(loginId[0] || 'T').toUpperCase()}</div><div><b>{loginId || 'Teacher'}</b><small>Teacher account</small></div><span className="account-tag">ACTIVE</span></div><label className="field-label readonly-label">Teacher ID<input value={loginId} readOnly /></label></section><section className="panel settings-card"><div className="settings-card-heading"><span className="settings-icon security"><Icon name="lock" size={18} /></span><div><h2>Change password</h2><p>Choose a password with at least 8 characters.</p></div></div><form className="form-stack settings-form" onSubmit={onSubmit}><label className="field-label">Current password<PasswordField value={password.currentPassword} onChange={(value) => setPassword({ ...password, currentPassword: value })} /></label><label className="field-label">New password<PasswordField value={password.newPassword} autoComplete="new-password" minLength={8} onChange={(value) => setPassword({ ...password, newPassword: value })} /></label><label className="field-label">Confirm new password<PasswordField value={password.confirmPassword} autoComplete="new-password" minLength={8} onChange={(value) => setPassword({ ...password, confirmPassword: value })} /></label><button className="button primary" disabled={busy}>{busy ? 'Updating…' : 'Update password'} <Icon name="arrow" size={15} /></button></form></section><section className="panel connection-card"><span className="connection-dot" /><div><b>Studio connection</b><small>API endpoint</small></div><code>{apiBase}</code><span className="connected-label">CONNECTED</span></section></div></div>
}

function QuestionModal({ draft, setDraft, editing, busy, error, onClose, onSubmit }: { draft: QuestionDraft; setDraft: (draft: QuestionDraft) => void; editing: boolean; busy: boolean; error: string; onClose: () => void; onSubmit: (event: FormEvent) => void }) {
  const updatePair = (index: number, key: 'left' | 'right', value: string) => setDraft({ ...draft, pairs: draft.pairs.map((pair, i) => i === index ? { ...pair, [key]: value } : pair) })
  const canSubmit = draft.prompt.trim() && (draft.type === 'matching' ? draft.pairs.length > 0 && draft.pairs.every((pair) => pair.left.trim() && pair.right.trim()) : draft.options.length >= 2 && draft.options.every((option) => option.trim()) && draft.answer && draft.options.includes(draft.answer))
  return <Modal title={editing ? 'Edit this question' : 'Create a question'} subtitle={editing ? 'Changes here apply to this game only.' : 'Make a prompt learners can explore and enjoy.'} error={error} onClose={onClose} wide><form className="form-stack question-form" onSubmit={onSubmit}><label className="field-label">Your question<textarea autoFocus required maxLength={2000} rows={2} placeholder="What would you like learners to think about?" value={draft.prompt} onChange={(event) => setDraft({ ...draft, prompt: event.target.value })} /></label><div className="question-type-switch"><button type="button" className={draft.type === 'multiple_choice' ? 'active' : ''} onClick={() => setDraft({ ...draft, type: 'multiple_choice' })}><span className="type-letter">A</span> Multiple choice</button><button type="button" className={draft.type === 'matching' ? 'active' : ''} onClick={() => setDraft({ ...draft, type: 'matching' })}><span className="type-link">↔</span> Matching pairs</button></div>{draft.type === 'multiple_choice' ? <div className="answer-builder"><div className="builder-label"><b>Answer choices</b><small>Pick the correct answer with the circle.</small></div>{draft.options.map((option, index) => <div className="choice-input" key={index}><button type="button" className={`answer-radio ${draft.answer === option && option ? 'chosen' : ''}`} aria-label={`Mark answer ${index + 1} correct`} onClick={() => setDraft({ ...draft, answer: option })}><span /></button><input required placeholder={`Choice ${String.fromCharCode(65 + index)}`} value={option} onChange={(event) => { const old = option; const value = event.target.value; setDraft({ ...draft, options: draft.options.map((choice, i) => i === index ? value : choice), answer: draft.answer === old ? value : draft.answer }) }} /><span className="choice-letter">{String.fromCharCode(65 + index)}</span>{draft.options.length > 2 && <button type="button" className="icon-button remove" aria-label="Remove answer choice" onClick={() => { const next = draft.options.filter((_, i) => i !== index); setDraft({ ...draft, options: next, answer: draft.answer === option ? '' : draft.answer }) }}><Icon name="close" size={15} /></button>}</div>)}{draft.options.length < 6 && <button type="button" className="add-choice" onClick={() => setDraft({ ...draft, options: [...draft.options, ''] })}><Icon name="plus" size={15} /> Add another choice</button>}<small className="answer-hint">{draft.answer ? 'Correct answer selected' : 'Select the circle next to the correct answer.'}</small></div> : <div className="answer-builder"><div className="builder-label"><b>Things to match</b><small>Each left item connects to its partner on the right.</small></div>{draft.pairs.map((pair, index) => <div className="pair-input" key={index}><span className="pair-index">{String(index + 1).padStart(2, '0')}</span><input required placeholder="First thing" value={pair.left} onChange={(event) => updatePair(index, 'left', event.target.value)} /><span className="pair-connector">↔</span><input required placeholder="Matches with" value={pair.right} onChange={(event) => updatePair(index, 'right', event.target.value)} />{draft.pairs.length > 1 && <button type="button" className="icon-button remove" aria-label="Remove matching pair" onClick={() => setDraft({ ...draft, pairs: draft.pairs.filter((_, i) => i !== index) })}><Icon name="close" size={15} /></button>}</div>)}<button type="button" className="add-choice" onClick={() => setDraft({ ...draft, pairs: [...draft.pairs, { left: '', right: '' }] })}><Icon name="plus" size={15} /> Add another pair</button></div>}<div className="modal-actions"><button type="button" className="button quiet" onClick={onClose}>Cancel</button><button className="button primary" disabled={!canSubmit || busy}>{busy ? 'Saving…' : editing ? 'Save question' : 'Save question'} <Icon name="arrow" size={15} /></button></div></form></Modal>
}

function Modal({ title, subtitle, children, onClose, error, wide = false }: { title: string; subtitle: string; children: ReactNode; onClose: () => void; error?: string; wide?: boolean }) {
  useEffect(() => { const closeOnEscape = (event: KeyboardEvent) => { if (event.key === 'Escape') onClose() }; window.addEventListener('keydown', closeOnEscape); return () => window.removeEventListener('keydown', closeOnEscape) }, [onClose])
  return <div className="modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose() }}><section className={`modal ${wide ? 'modal-wide' : ''}`} role="dialog" aria-modal="true" aria-labelledby="modal-title"><button className="modal-close icon-button" aria-label="Close dialog" onClick={onClose}><Icon name="close" /></button><div className="modal-heading"><span className="eyebrow">TINYTRAIL WORKSHOP</span><h2 id="modal-title">{title}</h2><p>{subtitle}</p></div>{error && <div className="alert error-alert modal-error" role="alert">{error}</div>}{children}</section></div>
}

function StatusPill({ status }: { status: 'draft' | 'published' }) {
  return <span className={`status-pill ${status}`}><i />{status === 'draft' ? 'Draft' : 'Published'}</span>
}

function EmptyState({ icon, title, detail, action }: { icon: string; title: string; detail: string; action?: ReactNode }) {
  return <div className="empty-state"><span className="empty-icon"><Icon name={icon} size={23} /></span><h3>{title}</h3><p>{detail}</p>{action}</div>
}

function formatDate(value?: string) {
  if (!value) return 'just now'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return 'recently'
  return new Intl.DateTimeFormat('en', { month: 'short', day: 'numeric' }).format(date)
}

export default App

