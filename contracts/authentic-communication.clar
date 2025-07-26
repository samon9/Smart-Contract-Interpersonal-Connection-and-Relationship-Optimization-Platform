;; Authentic Communication Facilitation Contract
;; Promotes honest, vulnerable, and meaningful dialogue

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-USER-NOT-FOUND (err u201))
(define-constant ERR-INVALID-INPUT (err u202))
(define-constant ERR-CONVERSATION-NOT-FOUND (err u203))
(define-constant ERR-ALREADY-PARTICIPATED (err u204))

;; Data Variables
(define-data-var total-conversations uint u0)
(define-data-var authenticity-threshold uint u70)

;; Data Maps
(define-map communication-profiles
  principal
  {
    authenticity-score: uint,
    vulnerability-level: uint,
    meaningful-conversations: uint,
    honesty-rating: uint,
    last-assessment: uint
  }
)

(define-map conversation-sessions
  uint
  {
    initiator: principal,
    participant: (optional principal),
    topic: (string-ascii 200),
    authenticity-rating: uint,
    vulnerability-demonstrated: bool,
    meaningful-outcome: bool,
    duration: uint,
    timestamp: uint,
    status: (string-ascii 20)
  }
)

(define-map communication-assessments
  {user: principal, assessment-id: uint}
  {
    honesty-score: uint,
    vulnerability-score: uint,
    empathy-score: uint,
    clarity-score: uint,
    assessor: principal,
    feedback: (string-ascii 300),
    timestamp: uint
  }
)

(define-map authenticity-achievements
  principal
  {
    honest-communicator: bool,
    vulnerable-sharer: bool,
    empathetic-listener: bool,
    meaningful-connector: bool,
    total-authenticity-points: uint
  }
)

;; Public Functions

;; Initialize communication profile
(define-public (create-communication-profile)
  (let ((caller tx-sender))
    (asserts! (is-none (map-get? communication-profiles caller)) ERR-ALREADY-PARTICIPATED)

    (map-set communication-profiles caller {
      authenticity-score: u50,
      vulnerability-level: u30,
      meaningful-conversations: u0,
      honesty-rating: u50,
      last-assessment: block-height
    })

    (map-set authenticity-achievements caller {
      honest-communicator: false,
      vulnerable-sharer: false,
      empathetic-listener: false,
      meaningful-connector: false,
      total-authenticity-points: u0
    })

    (ok true)
  )
)

;; Start an authentic conversation session
(define-public (initiate-conversation (topic (string-ascii 200)))
  (let ((caller tx-sender)
        (conversation-id (+ (var-get total-conversations) u1)))

    (asserts! (is-some (map-get? communication-profiles caller)) ERR-USER-NOT-FOUND)
    (asserts! (> (len topic) u0) ERR-INVALID-INPUT)

    (map-set conversation-sessions conversation-id {
      initiator: caller,
      participant: none,
      topic: topic,
      authenticity-rating: u0,
      vulnerability-demonstrated: false,
      meaningful-outcome: false,
      duration: u0,
      timestamp: block-height,
      status: "open"
    })

    (var-set total-conversations conversation-id)
    (ok conversation-id)
  )
)

;; Join an existing conversation
(define-public (join-conversation (conversation-id uint))
  (let ((caller tx-sender)
        (conversation (unwrap! (map-get? conversation-sessions conversation-id) ERR-CONVERSATION-NOT-FOUND)))

    (asserts! (is-some (map-get? communication-profiles caller)) ERR-USER-NOT-FOUND)
    (asserts! (not (is-eq caller (get initiator conversation))) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (get participant conversation)) ERR-ALREADY-PARTICIPATED)
    (asserts! (is-eq (get status conversation) "open") ERR-NOT-AUTHORIZED)

    (map-set conversation-sessions conversation-id
      (merge conversation {
        participant: (some caller),
        status: "active"
      })
    )

    (ok true)
  )
)

;; Complete conversation with ratings
(define-public (complete-conversation (conversation-id uint) (authenticity-rating uint) (was-vulnerable bool) (was-meaningful bool) (duration uint))
  (let ((caller tx-sender)
        (conversation (unwrap! (map-get? conversation-sessions conversation-id) ERR-CONVERSATION-NOT-FOUND)))

    (asserts! (or (is-eq caller (get initiator conversation))
                  (is-eq (some caller) (get participant conversation))) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= authenticity-rating u1) (<= authenticity-rating u10)) ERR-INVALID-INPUT)
    (asserts! (> duration u0) ERR-INVALID-INPUT)

    (map-set conversation-sessions conversation-id
      (merge conversation {
        authenticity-rating: authenticity-rating,
        vulnerability-demonstrated: was-vulnerable,
        meaningful-outcome: was-meaningful,
        duration: duration,
        status: "completed"
      })
    )

    ;; Update profiles for both participants
    (try! (update-communication-stats (get initiator conversation) authenticity-rating was-vulnerable was-meaningful))
    (match (get participant conversation)
      participant-addr (try! (update-communication-stats participant-addr authenticity-rating was-vulnerable was-meaningful))
      true
    )

    (ok true)
  )
)

;; Submit communication assessment
(define-public (assess-communication (user principal) (assessment-id uint) (honesty uint) (vulnerability uint) (empathy uint) (clarity uint) (feedback (string-ascii 300)))
  (let ((assessor tx-sender))
    (asserts! (not (is-eq assessor user)) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? communication-profiles user)) ERR-USER-NOT-FOUND)
    (asserts! (and (>= honesty u1) (<= honesty u10)) ERR-INVALID-INPUT)
    (asserts! (and (>= vulnerability u1) (<= vulnerability u10)) ERR-INVALID-INPUT)
    (asserts! (and (>= empathy u1) (<= empathy u10)) ERR-INVALID-INPUT)
    (asserts! (and (>= clarity u1) (<= clarity u10)) ERR-INVALID-INPUT)

    (map-set communication-assessments {user: user, assessment-id: assessment-id} {
      honesty-score: honesty,
      vulnerability-score: vulnerability,
      empathy-score: empathy,
      clarity-score: clarity,
      assessor: assessor,
      feedback: feedback,
      timestamp: block-height
    })

    ;; Update user's overall scores
    (try! (update-overall-scores user honesty vulnerability empathy clarity))

    (ok true)
  )
)

;; Private Functions

;; Update communication statistics after conversation
(define-private (update-communication-stats (user principal) (authenticity uint) (vulnerable bool) (meaningful bool))
  (let ((profile (unwrap! (map-get? communication-profiles user) ERR-USER-NOT-FOUND)))

    (let ((new-profile (merge profile {
      authenticity-score: (calculate-weighted-average (get authenticity-score profile) authenticity (get meaningful-conversations profile)),
      vulnerability-level: (if vulnerable
                       (let ((new-vuln (+ (get vulnerability-level profile) u5)))
                         (if (> new-vuln u100) u100 new-vuln))
                       (get vulnerability-level profile)),
      meaningful-conversations: (if meaningful
                                  (+ (get meaningful-conversations profile) u1)
                                  (get meaningful-conversations profile))
    })))

      (map-set communication-profiles user new-profile)
      (try! (check-authenticity-achievements user))
      (ok true)
    )
  )
)

;; Update overall scores from assessments
(define-private (update-overall-scores (user principal) (honesty uint) (vulnerability uint) (empathy uint) (clarity uint))
  (let ((profile (unwrap! (map-get? communication-profiles user) ERR-USER-NOT-FOUND)))

    (let ((conversations (get meaningful-conversations profile))
          (new-honesty (calculate-weighted-average (get honesty-rating profile) honesty conversations))
          (new-vulnerability (calculate-weighted-average (get vulnerability-level profile) (* vulnerability u10) conversations))
          (new-authenticity (/ (+ new-honesty new-vulnerability empathy clarity) u4)))

      (map-set communication-profiles user
        (merge profile {
          honesty-rating: new-honesty,
          vulnerability-level: new-vulnerability,
          authenticity-score: new-authenticity,
          last-assessment: block-height
        })
      )

      (ok true)
    )
  )
)

;; Calculate weighted average for score updates
(define-private (calculate-weighted-average (current-score uint) (new-score uint) (weight uint))
  (if (is-eq weight u0)
    new-score
    (/ (+ (* current-score weight) new-score) (+ weight u1))
  )
)

;; Check and award authenticity achievements
(define-private (check-authenticity-achievements (user principal))
  (let ((profile (unwrap! (map-get? communication-profiles user) ERR-USER-NOT-FOUND))
        (achievements (unwrap! (map-get? authenticity-achievements user) ERR-USER-NOT-FOUND)))

    (let ((new-achievements (merge achievements {
      honest-communicator: (or (get honest-communicator achievements) (>= (get honesty-rating profile) u80)),
      vulnerable-sharer: (or (get vulnerable-sharer achievements) (>= (get vulnerability-level profile) u70)),
      empathetic-listener: (or (get empathetic-listener achievements) (>= (get authenticity-score profile) u75)),
      meaningful-connector: (or (get meaningful-connector achievements) (>= (get meaningful-conversations profile) u10)),
      total-authenticity-points: (calculate-authenticity-points profile)
    })))

      (map-set authenticity-achievements user new-achievements)
      (ok true)
    )
  )
)

;; Calculate total authenticity points
(define-private (calculate-authenticity-points (profile {authenticity-score: uint, vulnerability-level: uint, meaningful-conversations: uint, honesty-rating: uint, last-assessment: uint}))
  (+ (get authenticity-score profile)
     (get vulnerability-level profile)
     (* (get meaningful-conversations profile) u5)
     (get honesty-rating profile))
)

;; Read-only Functions

;; Get communication profile
(define-read-only (get-communication-profile (user principal))
  (map-get? communication-profiles user)
)

;; Get conversation details
(define-read-only (get-conversation (conversation-id uint))
  (map-get? conversation-sessions conversation-id)
)

;; Get communication assessment
(define-read-only (get-assessment (user principal) (assessment-id uint))
  (map-get? communication-assessments {user: user, assessment-id: assessment-id})
)

;; Get authenticity achievements
(define-read-only (get-achievements (user principal))
  (map-get? authenticity-achievements user)
)

;; Get total conversations
(define-read-only (get-total-conversations)
  (var-get total-conversations)
)

;; Admin Functions

;; Update authenticity threshold
(define-public (set-authenticity-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= new-threshold u50) (<= new-threshold u90)) ERR-INVALID-INPUT)
    (var-set authenticity-threshold new-threshold)
    (ok new-threshold)
  )
)
