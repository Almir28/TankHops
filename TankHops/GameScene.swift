//
//  GameScene.swift
//  TankGame
//
//  Created by ChatGPT on 22.12.2024.
//

import SpriteKit

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - Узлы
    private var playerTank: SKNode?
    var enemyTanks: [SKNode] = []           // Массив вражеских танков
    
    // Флаги для физики
    let playerCategory: UInt32 = 0x1 << 0    // 1
    let enemyCategory: UInt32 = 0x1 << 1     // 2
    let playerBulletCategory: UInt32 = 0x1 << 2  // 4
    let enemyBulletCategory: UInt32 = 0x1 << 3   // 8
    let medkitCategory: UInt32 = 0x1 << 4    // 16
    
    // MARK: - Параметры спавна
    var spawnCount = 0                       // Сколько врагов уже заспавнилось
    let maxEnemies = 100                    // Лимит врагов на "уровень"

    // MARK: - Жизни игрока
    private var playerLivesLabel: SKLabelNode?
    var playerLives = 3 {
        didSet {
            playerLivesLabel?.text = "Lives: \(playerLives)"
            if playerLives <= 0 {
                gameOver()
            }
        }
    }
    
    // MARK: - Счёт
    private var scoreLabel: SKLabelNode?
    var score = 0 {
        didSet {
            scoreLabel?.text = "Score: \(score)"
        }
    }
    
    // Добавим свойство для хранения активных пуль
    private var activeBullets: Set<SKNode> = []
    
    // Для плавного управления
    private var isTouchingTank = false
    private var lastTouchLocation: CGPoint?
    private var touchStartLocation: CGPoint?
    
    // Для перезапуска игры
    private var restartButton: SKNode?
    
    // Для улучшенного управления
    private var joystickNode: SKShapeNode?
    private var joystickKnob: SKShapeNode?
    private var isMoving = false
    private var moveSpeed: CGFloat = 150
    private var gameOverLabel: SKLabelNode?
    
    // Параметры игрока
    private var playerHealth: Int = 100 {
        didSet {
            updateHealthBar()
        }
    }
    private var healthBar: SKShapeNode?
    private var healthBarBackground: SKShapeNode?
    
    // Параметры уровней
    private var currentLevel = 1
    private var levelLabel: SKLabelNode?
    private var enemyFireRate: TimeInterval = 2.0
    
    // Категории для физики
    let powerupCategory: UInt32 = 0x1 << 5
    
    // Константы для управления
    private let minMoveDistance: CGFloat = 1.0
    private let maxMoveSpeed: CGFloat = 300.0
    private let minMoveSpeed: CGFloat = 150.0
    private let touchAreaSize: CGFloat = 44.0 // Минимальный размер для iOS
    
    // Константы для урона
    private let collisionDamage: Int = 30
    private let explosionRadius: CGFloat = 50.0
    
    // Обновим константы для разных типов взрывов
    private enum ExplosionType {
        case small  // Для снарядов
        case medium // Для танков
        case large  // Для особых эффектов
        
        var config: (scale: CGFloat, particles: Int, speed: CGFloat, duration: TimeInterval) {
            switch self {
            case .small:
                return (0.3, 15, 80, 0.2)  // Маленький быстрый взрыв
            case .medium:
                return (0.5, 25, 120, 0.3) // Средний взрыв
            case .large:
                return (0.7, 35, 150, 0.4) // Большой взрыв
            }
        }
    }
    
    // MARK: - didMove
    override func didMove(to view: SKView) {
        // Сначала настраиваем базовые параметры сцены
        self.size = view.bounds.size
        self.scaleMode = .aspectFill
        backgroundColor = .white
        
        // Настраиваем физику
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        
        // Инициализируем все компоненты
        initializeHUD()
        createPlayerTank()
        
        // Запускаем игровую логику только после инициализации
        startGame()
    }
    
    // Обновим метод initializeHUD для лучшего UI
    private func initializeHUD() {
        // Учитываем Dynamic Island и отступы
        let topSafeArea: CGFloat = 60 // Отступ для Dynamic Island
        let margin: CGFloat = 20
        
        // Создаем контейнер для счета
        let scoreContainer = SKShapeNode(rectOf: CGSize(width: 120, height: 40),
                                       cornerRadius: 10)
        scoreContainer.fillColor = UIColor.black.withAlphaComponent(0.5)
        scoreContainer.strokeColor = .white
        scoreContainer.lineWidth = 1
        scoreContainer.position = CGPoint(x: margin + 60,
                                        y: size.height - topSafeArea)
        addChild(scoreContainer)
        
        // Настраиваем счет
        scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        if let scoreLabel = scoreLabel {
            scoreLabel.fontSize = 20
            scoreLabel.fontColor = .white
            scoreLabel.verticalAlignmentMode = .center
            scoreLabel.position = scoreContainer.position
            scoreLabel.text = "Score: 0"
            scoreLabel.zPosition = 100
            addChild(scoreLabel)
        }
        
        // Создаем новый дизайн полоски здоровья
        let healthBarWidth: CGFloat = size.width * 0.4
        let healthBarHeight: CGFloat = 8
        
        healthBarBackground = SKShapeNode(rectOf: CGSize(width: healthBarWidth,
                                                        height: healthBarHeight),
                                        cornerRadius: 4)
        if let healthBg = healthBarBackground {
            healthBg.fillColor = UIColor.darkGray.withAlphaComponent(0.5)
            healthBg.strokeColor = .white
            healthBg.lineWidth = 1
            healthBg.position = CGPoint(x: size.width - healthBarWidth/2 - margin,
                                      y: size.height - topSafeArea)
            healthBg.zPosition = 90
            addChild(healthBg)
        }
        
        healthBar = SKShapeNode(rectOf: CGSize(width: healthBarWidth,
                                              height: healthBarHeight),
                               cornerRadius: 4)
        if let healthBar = healthBar {
            healthBar.fillColor = .systemGreen
            healthBar.strokeColor = .clear
            healthBar.position = healthBarBackground?.position ?? .zero
            healthBar.zPosition = 95
            addChild(healthBar)
        }
    }
    
    // MARK: - Создание танка игрока
    private func createPlayerTank() {
        let tank = SKNode()
        
        // Основной корпус (более детализированный)
        let bodyPath = UIBezierPath()
        bodyPath.move(to: CGPoint(x: -20, y: -15))
        bodyPath.addLine(to: CGPoint(x: 20, y: -15))
        bodyPath.addLine(to: CGPoint(x: 25, y: -10))
        bodyPath.addLine(to: CGPoint(x: 25, y: 5))
        bodyPath.addLine(to: CGPoint(x: 20, y: 10))
        bodyPath.addLine(to: CGPoint(x: -20, y: 10))
        bodyPath.addLine(to: CGPoint(x: -25, y: 5))
        bodyPath.addLine(to: CGPoint(x: -25, y: -10))
        bodyPath.close()
        
        let bodyShape = SKShapeNode(path: bodyPath.cgPath)
        bodyShape.fillColor = .systemGreen
        bodyShape.strokeColor = .darkGray
        bodyShape.lineWidth = 2
        bodyShape.name = "tankBody"
        
        // Гусеницы
        let leftTrack = SKShapeNode(rect: CGRect(x: -25, y: -15, width: 6, height: 30),
                                   cornerRadius: 3)
        leftTrack.fillColor = .darkGray
        leftTrack.strokeColor = .black
        leftTrack.lineWidth = 1
        
        let rightTrack = SKShapeNode(rect: CGRect(x: 19, y: -15, width: 6, height: 30),
                                    cornerRadius: 3)
        rightTrack.fillColor = .darkGray
        rightTrack.strokeColor = .black
        rightTrack.lineWidth = 1
        
        // Башня (более сложная форма)
        let turretPath = UIBezierPath()
        turretPath.move(to: CGPoint(x: -12, y: 0))
        turretPath.addLine(to: CGPoint(x: 12, y: 0))
        turretPath.addLine(to: CGPoint(x: 12, y: 15))
        turretPath.addLine(to: CGPoint(x: 8, y: 18))
        turretPath.addLine(to: CGPoint(x: -8, y: 18))
        turretPath.addLine(to: CGPoint(x: -12, y: 15))
        turretPath.close()
        
        let turretShape = SKShapeNode(path: turretPath.cgPath)
        turretShape.fillColor = .systemGreen
        turretShape.strokeColor = .darkGray
        turretShape.lineWidth = 2
        
        // Пушка
        let gunShape = SKShapeNode(rect: CGRect(x: -2, y: 18, width: 4, height: 15),
                                  cornerRadius: 1)
        gunShape.fillColor = .darkGray
        gunShape.strokeColor = .black
        gunShape.lineWidth = 1
        
        // Добавляем все части
        tank.addChild(leftTrack)
        tank.addChild(rightTrack)
        tank.addChild(bodyShape)
        tank.addChild(turretShape)
        tank.addChild(gunShape)
        
        // Позционирование и физика
        let startY = size.height * 0.2
        tank.position = CGPoint(x: size.width / 2, y: startY)
        tank.name = "playerTank"
        
        let tankBody = SKPhysicsBody(rectangleOf: CGSize(width: 40, height: 30))
        tankBody.isDynamic = true
        tankBody.affectedByGravity = false
        tankBody.categoryBitMask = playerCategory
        tankBody.contactTestBitMask = enemyCategory | enemyBulletCategory
        tankBody.collisionBitMask = 0
        tank.physicsBody = tankBody
        
        playerTank = tank
        
        if let playerTank = playerTank {
            addChild(playerTank)
        }
    }
    
    private func startGame() {
        if playerTank == nil {
            print("Error: Player tank not initialized")
            return
        }
        
        // Проверяем инициализацию UI компонентов
        if scoreLabel == nil || healthBar == nil {
            print("Error: UI components not initialized")
            return
        }
        
        // Настраиваем начальные параметры
        score = 0
        playerHealth = 100
        playerLives = 3
        spawnCount = 0
        
        // Обновляем UI
        updateUI()
        
        // Запускаем спавн врагов
        spawnEnemies()
    }
    
    // Безопасное обновление UI
    private func updateUI() {
        // Обновляем счет с анимацией
        if let scoreLabel = scoreLabel {
            let scaleUp = SKAction.scale(to: 1.2, duration: 0.1)
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
            scoreLabel.text = "Score: \(score)"
            scoreLabel.run(SKAction.sequence([scaleUp, scaleDown]))
        }
        
        // Обновляем жизни с визуальным эффектом
        if let livesLabel = playerLivesLabel {
            livesLabel.text = String(repeating: "❤️", count: playerLives)
            let fadeOut = SKAction.fadeAlpha(to: 0.5, duration: 0.1)
            let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.1)
            livesLabel.run(SKAction.sequence([fadeOut, fadeIn]))
        }
        
        updateHealthBar()
    }
    
    // Обновление полоски здоровья
    private func updateHealthBar() {
        guard let healthBar = healthBar else { return }
        
        let healthPercent = CGFloat(playerHealth) / 100.0
        let newWidth = 200 * healthPercent
        let newRect = CGRect(x: -100, y: -7.5,
                            width: newWidth, height: 15)
        healthBar.path = UIBezierPath(roundedRect: newRect,
                                     cornerRadius: 5).cgPath
        
        // зменение цвета в зависимости от здоровья
        if healthPercent > 0.7 {
            healthBar.fillColor = .green
        } else if healthPercent > 0.3 {
            healthBar.fillColor = .yellow
        } else {
            healthBar.fillColor = .red
        }
    }
    
    // MARK: - Спавн вражеского танка
    private func spawnEnemyTank() {
        let enemyTank = SKNode()
        
        // Корпус врага (более агрессивный дизайн)
        let bodyPath = UIBezierPath()
        bodyPath.move(to: CGPoint(x: -15, y: -10))
        bodyPath.addLine(to: CGPoint(x: 15, y: -10))
        bodyPath.addLine(to: CGPoint(x: 18, y: -5))
        bodyPath.addLine(to: CGPoint(x: 18, y: 5))
        bodyPath.addLine(to: CGPoint(x: 15, y: 8))
        bodyPath.addLine(to: CGPoint(x: -15, y: 8))
        bodyPath.addLine(to: CGPoint(x: -18, y: 5))
        bodyPath.addLine(to: CGPoint(x: -18, y: -5))
        bodyPath.close()
        
        let bodyShape = SKShapeNode(path: bodyPath.cgPath)
        bodyShape.fillColor = .systemRed
        bodyShape.strokeColor = .darkGray
        bodyShape.lineWidth = 1.5
        
        // Гусеницы врага
        let leftTrack = SKShapeNode(rect: CGRect(x: -18, y: -10, width: 4, height: 20),
                                   cornerRadius: 2)
        leftTrack.fillColor = .darkGray
        leftTrack.strokeColor = .black
        leftTrack.lineWidth = 1
        
        let rightTrack = SKShapeNode(rect: CGRect(x: 14, y: -10, width: 4, height: 20),
                                    cornerRadius: 2)
        rightTrack.fillColor = .darkGray
        rightTrack.strokeColor = .black
        rightTrack.lineWidth = 1
        
        // Башня врага
        let turretShape = SKShapeNode(rect: CGRect(x: -8, y: 0, width: 16, height: 12),
                                     cornerRadius: 3)
        turretShape.fillColor = .systemRed
        turretShape.strokeColor = .darkGray
        turretShape.lineWidth = 1.5
        turretShape.name = "turret"
        
        // Пушка врага
        let gunShape = SKShapeNode(rect: CGRect(x: -1.5, y: 12, width: 3, height: 10),
                                  cornerRadius: 1)
        gunShape.fillColor = .darkGray
        gunShape.strokeColor = .black
        gunShape.lineWidth = 1
        
        // Собираем танк врага
        enemyTank.addChild(leftTrack)
        enemyTank.addChild(rightTrack)
        enemyTank.addChild(bodyShape)
        turretShape.addChild(gunShape)
        enemyTank.addChild(turretShape)
        
        // Оптимизированный спавн
        let margin: CGFloat = 40
        let randomX = CGFloat.random(in: margin...(size.width - margin))
        enemyTank.position = CGPoint(x: randomX, y: size.height + 10)
        
        let physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 40, height: 30))
        physicsBody.isDynamic = true
        physicsBody.affectedByGravity = false
        physicsBody.categoryBitMask = enemyCategory
        physicsBody.contactTestBitMask = playerCategory | playerBulletCategory
        physicsBody.collisionBitMask = 0 // Отключаем физическую коллизию
        enemyTank.physicsBody = physicsBody
        
        enemyTank.name = "enemyTank"
        addChild(enemyTank)
        enemyTanks.append(enemyTank)
        
        // Упрощённое движение
        let moveAction = SKAction.moveTo(y: -50, duration: 7.0)
        let removeAction = SKAction.run { [weak self, weak enemyTank] in
            guard let self = self,
                  let tank = enemyTank else { return }
            tank.removeFromParent()
            self.enemyTanks.removeAll(where: { $0 == tank })
            self.playerLives -= 1
        }
        
        enemyTank.run(SKAction.sequence([moveAction, removeAction]))
        
        // Добавляем периодическую стрельбу
        let shootAction = SKAction.run { [weak self, weak enemyTank] in
            guard let self = self,
                  let enemy = enemyTank,
                  !self.isPaused,
                  enemy.parent != nil else { return }
            self.enemyShoot(from: enemy)
        }
        let waitAction = SKAction.wait(forDuration: 2.0) // Стреляем каждые 2 секунды
        let shootSequence = SKAction.sequence([waitAction, shootAction])
        enemyTank.run(SKAction.repeatForever(shootSequence))
    }
    
    // MARK: - Выстрел
    private func shoot() {
        guard let playerTank = playerTank else { return }
        
        // Ограничиваем количество пуль
        if activeBullets.count >= 3 { return }
        
        let bulletNode = SKNode()
        let bulletSize = CGSize(width: 4, height: 8)
        
        let bullet = SKShapeNode(rectOf: bulletSize, cornerRadius: 1)
        bullet.fillColor = .black
        bullet.strokeColor = .black
        bulletNode.addChild(bullet)
        
        // Позиционируем пулю относительно танка (из пушки)
        bulletNode.position = CGPoint(x: playerTank.position.x,
                                    y: playerTank.position.y + 25) // Увеличили смещение для выстрела из пушки
        
        // Настраиваем физику пули
        let bulletBody = SKPhysicsBody(rectangleOf: bulletSize)
        bulletBody.isDynamic = true
        bulletBody.affectedByGravity = false
        bulletBody.categoryBitMask = playerBulletCategory
        bulletBody.contactTestBitMask = enemyCategory
        bulletBody.collisionBitMask = 0
        bulletBody.usesPreciseCollisionDetection = true
        bulletNode.physicsBody = bulletBody
        
        activeBullets.insert(bulletNode)
        addChild(bulletNode)
        
        // Добавляем движение пули
        let moveAction = SKAction.moveBy(x: 0, y: size.height + 50, duration: 0.8)
        let removeAction = SKAction.run { [weak self, weak bulletNode] in
            guard let self = self,
                  let bullet = bulletNode else { return }
            bullet.removeFromParent()
            self.activeBullets.remove(bullet)
        }
        
        // Добавляем звук выстрела (опционально)
        let shootSound = SKAction.playSoundFileNamed("shoot.wav", waitForCompletion: false)
        
        // Запускаем последовательность действий
        bulletNode.run(SKAction.sequence([shootSound, moveAction, removeAction]))
        
        // Добавляем эффект отдачи танку
        let recoilUp = SKAction.moveBy(x: 0, y: -2, duration: 0.05)
        let recoilDown = SKAction.moveBy(x: 0, y: 2, duration: 0.05)
        playerTank.run(SKAction.sequence([recoilUp, recoilDown]))
        
        // Устанавливаем скорость пули
        bulletBody.velocity = CGVector(dx: 0, dy: 400)
    }
    
    // MARK: - touches
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if isPaused {
            handlePausedTouches(at: location)
            return
        }
        
        // Увеличиваем область касания для танка
        let touchRect = CGRect(x: location.x - touchAreaSize/2,
                             y: location.y - touchAreaSize/2,
                             width: touchAreaSize,
                             height: touchAreaSize)
        
        if let playerTank = playerTank {
            if touchRect.contains(playerTank.position) {
                isTouchingTank = true
                shoot() // Стреляем при касании танка
            } else {
                isMoving = true
                lastTouchLocation = location
                moveTankTo(point: location)
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              !isPaused else { return }
        
        let location = touch.location(in: self)
        
        if isTouchingTank {
            // Можно добавить автоматическую стрельбу при удержании
            if arc4random_uniform(100) < 10 { // 10% шанс выстрела ри каждом обновлении
                shoot()
            }
        } else if isMoving {
            lastTouchLocation = location
            moveTankTo(point: location)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isMoving = false
        isTouchingTank = false
    }
    
    // MARK: - Свободное перемещение танка
    private func moveTankTo(point: CGPoint) {
        guard let tank = playerTank else { return }
        
        // Ограничения движения с учетом размера танка
        let tankHalfWidth: CGFloat = 25
        let tankHalfHeight: CGFloat = 20
        let minY: CGFloat = tankHalfHeight + 50
        let maxY: CGFloat = size.height * 0.4
        let margin: CGFloat = tankHalfWidth + 10
        
        let targetX = min(max(point.x, margin), size.width - margin)
        let targetY = min(max(point.y, minY), maxY)
        let targetPoint = CGPoint(x: targetX, y: targetY)
        
        // Плавное движение с адаптивной скоростью
        let currentPos = tank.position
        let dx = targetPoint.x - currentPos.x
        let dy = targetPoint.y - currentPos.y
        let distance = sqrt(dx*dx + dy*dy)
        
        if distance < minMoveDistance { return }
        
        // Адаптивная скорость: быстрее на большие расстояния
        let speedFactor = min(distance / 100.0, 1.0)
        let speed = minMoveSpeed + (maxMoveSpeed - minMoveSpeed) * speedFactor
        
        let normalizedDx = dx / distance
        let normalizedDy = dy / distance
        
        let newX = currentPos.x + (normalizedDx * speed * 0.016)
        let newY = currentPos.y + (normalizedDy * speed * 0.016)
        
        tank.position = CGPoint(x: newX, y: newY)
    }
    
    // MARK: - SKPhysicsContactDelegate
    func didBegin(_ contact: SKPhysicsContact) {
        let firstBody = contact.bodyA
        let secondBody = contact.bodyB
        
        // Столкновение с вражеским танком
        if (firstBody.categoryBitMask == playerCategory && 
            secondBody.categoryBitMask == enemyCategory) ||
           (firstBody.categoryBitMask == enemyCategory && 
            secondBody.categoryBitMask == playerCategory) {
            
            let enemyNode = firstBody.categoryBitMask == enemyCategory ? 
                           firstBody.node : secondBody.node
            let playerNode = firstBody.categoryBitMask == playerCategory ? 
                           firstBody.node : secondBody.node
            
            if let enemy = enemyNode,
               let player = playerNode {
                // Создаем взрыв большого размера
                createExplosion(at: enemy.position, type: .large)
                
                // Наносим урон игроку
                damagePlayer(amount: collisionDamage)
                
                // Удаляем вражеский танк
                enemy.removeFromParent()
                if let index = enemyTanks.firstIndex(of: enemy) {
                    enemyTanks.remove(at: index)
                }
                
                // Добавляем эффект отбрасывания игрока
                let dx = player.position.x - enemy.position.x
                let dy = player.position.y - enemy.position.y
                let distance = sqrt(dx*dx + dy*dy)
                let knockbackForce: CGFloat = 100
                
                if distance > 0 {
                    let knockbackX = (dx / distance) * knockbackForce
                    let knockbackY = (dy / distance) * knockbackForce
                    
                    let knockbackAction = SKAction.move(by: CGVector(dx: knockbackX, dy: knockbackY),
                                                      duration: 0.1)
                    player.run(knockbackAction)
                }
            }
        }
        
        // Попадание вражеской пули
        if firstBody.categoryBitMask == playerCategory &&
           secondBody.node?.name == "enemyBullet" {
            if let bulletPosition = secondBody.node?.position {
                // Создаем маленький взрыв
                createExplosion(at: bulletPosition, type: .small)
                secondBody.node?.removeFromParent()
                damagePlayer(amount: 10)
            }
        }
        
        // Столкновение пули игрока с врагом
        if (firstBody.categoryBitMask == playerBulletCategory && 
            secondBody.categoryBitMask == enemyCategory) ||
           (firstBody.categoryBitMask == enemyCategory && 
            secondBody.categoryBitMask == playerBulletCategory) {
            
            let bullet = firstBody.categoryBitMask == playerBulletCategory ? 
                        firstBody.node : secondBody.node
            let enemy = firstBody.categoryBitMask == enemyCategory ? 
                       firstBody.node : secondBody.node
            
            handleBulletEnemyCollision(bullet: bullet, enemy: enemy)
        }
        
        // Столкновение вражеской пули с игроком
        if (firstBody.categoryBitMask == enemyBulletCategory && 
            secondBody.categoryBitMask == playerCategory) ||
           (firstBody.categoryBitMask == playerCategory && 
            secondBody.categoryBitMask == enemyBulletCategory) {
            
            let bullet = firstBody.categoryBitMask == enemyBulletCategory ? 
                        firstBody.node : secondBody.node
            bullet?.removeFromParent()
            damagePlayer(amount: 10)
        }
    }
    
    // Добавим новый метод для обработки столкновения с врагом
    private func handlePlayerEnemyCollision() {
        playerLives -= 1
    }
    
    // Добавим метод для обработки столкновения пули с врагом
    private func handleBulletEnemyCollision(bullet: SKNode?, enemy: SKNode?) {
        guard let bullet = bullet,
              let enemy = enemy else { return }
        
        // Удаляем пулю
        bullet.removeFromParent()
        activeBullets.remove(bullet)
        
        // Удаляем врага
        enemy.removeFromParent()
        if let index = enemyTanks.firstIndex(of: enemy) {
            enemyTanks.remove(at: index)
        }
        
        // Увеличиваем счёт
        score += 1
    }
    
    // MARK: - update
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        
        if playerTank == nil { return }
        
        if isMoving, let lastLocation = lastTouchLocation {
            moveTankTo(point: lastLocation)
        }
        
        updateEnemyTurrets()
    }
    
    private func updateEnemyTurrets() {
        let visibleEnemies = enemyTanks.prefix(10)
        for enemy in visibleEnemies {
            updateEnemyTurret(enemy)
        }
    }
    
    private func updateEnemyTurret(_ enemy: SKNode) {
        guard let playerTank = playerTank,
              let turret = enemy.childNode(withName: "turret") else { return }
        
        let dx = playerTank.position.x - enemy.position.x
        let dy = playerTank.position.y - enemy.position.y
        turret.zRotation = atan2(dy, dx) - .pi/2
    }
    
    // MARK: - Ограничиваем выход танка за рамки
    private func clampPlayerTankPosition() {
        // Учитываем половину габаритов танка (40×30 => половина 20×15)
        let halfW: CGFloat = 20
        let halfH: CGFloat = 15
        
        var pos = playerTank?.position ?? CGPoint.zero
        // По X
        if pos.x < halfW { pos.x = halfW }
        if pos.x > size.width - halfW { pos.x = size.width - halfW }
        
        // По Y
        if pos.y < halfH { pos.y = halfH }
        if pos.y > size.height - halfH { pos.y = size.height - halfH }
        
        playerTank?.position = pos
    }
    
    // MARK: - Game Over
    private func gameOver() {
        isPaused = true
        
        // Game Over надпись
        let gameOverLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        gameOverLabel.text = "GAME OVER"
        gameOverLabel.fontColor = .black
        gameOverLabel.fontSize = 40
        gameOverLabel.position = CGPoint(x: size.width / 2,
                                       y: size.height / 2 + 50)
        addChild(gameOverLabel)
        self.gameOverLabel = gameOverLabel // Сохраняем сылку
        
        // Создаем кнопку рестарта
        let button = SKShapeNode(rectOf: CGSize(width: 200, height: 50),
                                cornerRadius: 10)
        button.fillColor = .green
        button.strokeColor = .darkGray
        button.lineWidth = 2
        button.position = CGPoint(x: size.width / 2,
                                y: size.height / 2 - 50)
        
        let buttonLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        buttonLabel.text = "RESTART"
        buttonLabel.fontColor = .white
        buttonLabel.fontSize = 24
        buttonLabel.verticalAlignmentMode = .center
        button.addChild(buttonLabel)
        
        button.name = "restartButton"
        addChild(button)
        restartButton = button
    }
    
    // Добавляем метод перезапуска игры
    private func restartGame() {
        // Удаляем Game Over надпись
        gameOverLabel?.removeFromParent()
        gameOverLabel = nil
        
        // Очищаем сцену
        enemyTanks.forEach { $0.removeFromParent() }
        enemyTanks.removeAll()
        activeBullets.forEach { $0.removeFromParent() }
        activeBullets.removeAll()
        restartButton?.removeFromParent()
        restartButton = nil
        
        // Срасываем параметры
        score = 0
        playerLives = 3
        spawnCount = 0
        isMoving = false
        
        // Возвращаем танк на начальную позицию
        let startY = size.height * 0.2
        playerTank?.position = CGPoint(x: size.width / 2, y: startY)
        
        // Восстанавливаем здоровье
        playerHealth = 100
        
        // Возобновляем игру
        isPaused = false
    }
    
    // Добавим метод для очистки удалённых объектов
    override func didFinishUpdate() {
        super.didFinishUpdate()
        
        // Очищаем мссив врагов от удалённых нодов
        enemyTanks.removeAll { $0.parent == nil }
        
        // Очищаем множество пуль от удалённых нодов
        activeBullets = activeBullets.filter { $0.parent != nil }
    }
    
    // Добавим спвн аптечек
    private func spawnMedkit() {
        let medkit = SKShapeNode(rectOf: CGSize(width: 20, height: 20),
                                cornerRadius: 5)
        medkit.fillColor = .white
        medkit.strokeColor = .red
        medkit.lineWidth = 2
        
        // Красный крест
        let cross1 = SKShapeNode(rectOf: CGSize(width: 4, height: 14))
        let cross2 = SKShapeNode(rectOf: CGSize(width: 14, height: 4))
        cross1.fillColor = .red
        cross2.fillColor = .red
        medkit.addChild(cross1)
        medkit.addChild(cross2)
        
        // Случайная позиция
        let margin: CGFloat = 50
        let randomX = CGFloat.random(in: margin...(size.width - margin))
        let randomY = CGFloat.random(in: margin...(size.height - margin))
        medkit.position = CGPoint(x: randomX, y: randomY)
        
        // Физика
        let body = SKPhysicsBody(rectangleOf: CGSize(width: 20, height: 20))
        body.isDynamic = false
        body.categoryBitMask = medkitCategory
        body.contactTestBitMask = playerCategory
        medkit.physicsBody = body
        
        medkit.name = "medkit"
        addChild(medkit)
        
        // Удаление через 5 секунд
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let remove = SKAction.removeFromParent()
        let wait = SKAction.wait(forDuration: 5)
        medkit.run(SKAction.sequence([wait, fadeOut, remove]))
    }
    
    // Добавим стрельбу врагов
    private func enemyShoot(from enemy: SKNode) {
        guard let playerTank = playerTank else { return }
        
        let bulletNode = SKNode()
        bulletNode.name = "enemyBullet"
        
        let bulletSize = CGSize(width: 4, height: 8)
        let bullet = SKShapeNode(rectOf: bulletSize, cornerRadius: 1)
        bullet.fillColor = .red
        bullet.strokeColor = .red
        bulletNode.addChild(bullet)
        
        let startPos = enemy.convert(CGPoint(x: 0, y: 12), to: self)
        bulletNode.position = startPos
        
        let bulletBody = SKPhysicsBody(rectangleOf: bulletSize)
        bulletBody.isDynamic = true
        bulletBody.affectedByGravity = false
        bulletBody.categoryBitMask = enemyBulletCategory
        bulletBody.contactTestBitMask = playerCategory
        bulletBody.collisionBitMask = 0
        bulletBody.usesPreciseCollisionDetection = true
        bulletNode.physicsBody = bulletBody
        
        addChild(bulletNode)
        
        let dx = playerTank.position.x - startPos.x
        let dy = playerTank.position.y - startPos.y
        let angle = atan2(dy, dx)
        
        let speed: CGFloat = 300
        bulletBody.velocity = CGVector(dx: cos(angle) * speed,
                                     dy: sin(angle) * speed)
        
        bulletNode.zRotation = angle + .pi/2
        
        let wait = SKAction.wait(forDuration: 2)
        let remove = SKAction.removeFromParent()
        bulletNode.run(SKAction.sequence([wait, remove]))
    }
    
    // Добавим метод получения урона
    private func damagePlayer(amount: Int) {
        playerHealth -= amount
        
        // Визуальный эффект получения урона
        let flashAction = SKAction.sequence([
            SKAction.colorize(with: .red, colorBlendFactor: 1.0, duration: 0.1),
            SKAction.wait(forDuration: 0.1),
            SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.1)
        ])
        
        playerTank?.run(flashAction)
        
        // Проверяем смерть игрока
        if playerHealth <= 0 {
            gameOver()
        }
    }
    
    // Добавим метод spawnEnemies()
    private func spawnEnemies() {
        // Останавливаем предыдущий спавн если был
        removeAction(forKey: "spawning")
        
        // Создаем последовательность действий для спавна
        let spawn = SKAction.run { [weak self] in
            guard let self = self else { return }
            if self.spawnCount < self.maxEnemies {
                self.spawnEnemyTank()
                self.spawnCount += 1
            }
        }
        
        let wait = SKAction.wait(forDuration: 2.0)
        let sequence = SKAction.sequence([wait, spawn])
        let spawnForever = SKAction.repeatForever(sequence)
        
        // Запускаем спавн с уникальным ключом
        run(spawnForever, withKey: "spawning")
    }
    
    // Добавим обработку касаний в паузе
    private func handlePausedTouches(at location: CGPoint) {
        if let restart = restartButton,
           restart.contains(location) {
            restartGame()
        }
    }
    
    // Обновим метод createExplosion для более компактного эффекта
    private func createExplosion(at position: CGPoint, type: ExplosionType = .medium) {
        let config = type.config
        
        // 1. Основной взрыв (компактный)
        let explosion = SKEmitterNode()
        explosion.particleTexture = SKTexture(imageNamed: "explosion_particle")
        explosion.particleBirthRate = 1000
        explosion.numParticlesToEmit = config.particles
        explosion.particleLifetime = 0.15
        explosion.particleLifetimeRange = 0.1
        explosion.particleSpeed = config.speed
        explosion.particleSpeedRange = config.speed/2
        explosion.emissionAngle = 0
        explosion.emissionAngleRange = .pi * 2
        explosion.particleAlpha = 0.8
        explosion.particleAlphaSpeed = -2
        explosion.particleScale = 0.2 * config.scale
        explosion.particleScaleRange = 0.1
        explosion.particleScaleSpeed = -0.3
        explosion.particleColorSequence = {
            let sequence = SKKeyframeSequence(keyframeValues: [
                UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 1), // Яркий центр
                UIColor(red: 1, green: 0.6, blue: 0, alpha: 1),   // Оранжевый
                UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.5) // Дым
            ], times: [0, 0.3, 1])
            sequence.interpolationMode = .linear
            return sequence
        }()
        explosion.targetNode = self
        
        // 2. Искры (минимальные)
        let sparks = SKEmitterNode()
        sparks.particleTexture = SKTexture(imageNamed: "spark_particle")
        sparks.particleBirthRate = 800
        sparks.numParticlesToEmit = config.particles
        sparks.particleLifetime = 0.2
        sparks.particleSpeed = config.speed
        sparks.particleSpeedRange = config.speed/2
        sparks.emissionAngle = 0
        sparks.emissionAngleRange = .pi * 2
        sparks.particleAlpha = 0.8
        sparks.particleAlphaSpeed = -2
        sparks.particleScale = 0.1 * config.scale
        sparks.particleScaleRange = 0.05
        sparks.particleColor = .yellow
        sparks.targetNode = self
        
        // Позиционируем эффекты
        [explosion, sparks].forEach {
            $0.position = position
            $0.zPosition = 100 // Поверх других элементов
            addChild($0)
        }
        
        // Компактная вспышка
        let flash = SKSpriteNode(color: .white, size: CGSize(width: 40 * config.scale,
                                                            height: 40 * config.scale))
        flash.position = position
        flash.alpha = 0.7
        flash.setScale(0.1)
        flash.blendMode = .add
        flash.zPosition = 99
        addChild(flash)
        
        // Быстрая анимация вспышки
        let scaleUp = SKAction.scale(to: 1.5, duration: 0.05)
        let fadeOut = SKAction.fadeOut(withDuration: 0.1)
        let remove = SKAction.removeFromParent()
        flash.run(SKAction.sequence([scaleUp, fadeOut, remove]))
        
        // Быстрое удаление эффектов
        let wait = SKAction.wait(forDuration: config.duration)
        let cleanup = SKAction.run {
            [explosion, sparks].forEach { $0.removeFromParent() }
        }
        run(SKAction.sequence([wait, cleanup]))
    }
}
