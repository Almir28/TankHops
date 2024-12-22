//
//  GameScene.swift
//  TankGame
//
//  Created by ChatGPT on 22.12.2024.
//

import SpriteKit

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - Узлы
    var playerTank: SKNode!                 // Танк игрока
    var enemyTanks: [SKNode] = []           // Массив вражеских танков
    
    // Флаги для физики
    let bulletCategory:  UInt32 = 0x1 << 0   // Пули
    let enemyCategory:   UInt32 = 0x1 << 1   // Враги
    let playerCategory:  UInt32 = 0x1 << 2   // Игрок (если понадобится)

    // MARK: - Параметры спавна
    var spawnCount = 0                       // Сколько врагов уже заспавнилось
    let maxEnemies = 100                    // Лимит врагов на "уровень"

    // MARK: - Жизни игрока
    var playerLivesLabel: SKLabelNode!
    var playerLives = 3 {
        didSet {
            playerLivesLabel.text = "Lives: \(playerLives)"
            if playerLives <= 0 {
                gameOver()
            }
        }
    }
    
    // MARK: - Счёт
    var scoreLabel: SKLabelNode!
    var score = 0 {
        didSet {
            scoreLabel.text = "Score: \(score)"
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
    
    // MARK: - didMove
    override func didMove(to view: SKView) {
        // Настройки сцены
        self.size = view.bounds.size
        self.scaleMode = .aspectFill
        
        // Оптимизация физики
        physicsWorld.speed = 1.0
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        
        // Добавляем границы экрана
        let borderBody = SKPhysicsBody(edgeLoopFrom: self.frame)
        borderBody.friction = 0
        borderBody.restitution = 0
        borderBody.categoryBitMask = 0
        borderBody.collisionBitMask = 0
        self.physicsBody = borderBody
        
        backgroundColor = .white
        
        // Создаём объекты
        createPlayerTank()
        createHUD()
        
        // Оптимизируем спавн врагов
        let spawn = SKAction.run { [weak self] in
            guard let self = self else { return }
            if self.spawnCount < self.maxEnemies {
                self.spawnEnemyTank()
                self.spawnCount += 1
            }
        }
        let wait = SKAction.wait(forDuration: 2.0) // Увеличиваем интервал
        run(SKAction.repeatForever(SKAction.sequence([spawn, wait])))
    }
    
    // MARK: - Создание танка игрока
    private func createPlayerTank() {
        playerTank = SKNode()
        
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
        playerTank.addChild(leftTrack)
        playerTank.addChild(rightTrack)
        playerTank.addChild(bodyShape)
        playerTank.addChild(turretShape)
        playerTank.addChild(gunShape)
        
        // Позиционирование и физика
        let startY = size.height * 0.2
        playerTank.position = CGPoint(x: size.width / 2, y: startY)
        playerTank.name = "playerTank"
        
        let tankBody = SKPhysicsBody(rectangleOf: CGSize(width: 50, height: 40))
        tankBody.isDynamic = false
        tankBody.categoryBitMask = playerCategory
        tankBody.contactTestBitMask = enemyCategory
        tankBody.collisionBitMask = 0
        playerTank.physicsBody = tankBody
        
        addChild(playerTank)
    }
    
    // MARK: - Создание интерфейса (HUD)
    private func createHUD() {
        // Счёт
        scoreLabel = SKLabelNode(fontNamed: "Helvetica")
        scoreLabel.fontSize = 20
        scoreLabel.fontColor = .black
        scoreLabel.position = CGPoint(x: 60, y: size.height - 40)
        scoreLabel.text = "Score: \(score)"
        addChild(scoreLabel)
        
        // Жизни
        playerLivesLabel = SKLabelNode(fontNamed: "Helvetica")
        playerLivesLabel.fontSize = 20
        playerLivesLabel.fontColor = .red
        playerLivesLabel.position = CGPoint(x: size.width - 60,
                                            y: size.height - 40)
        playerLivesLabel.text = "Lives: \(playerLives)"
        addChild(playerLivesLabel)
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
        
        let physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 20, height: 16))
        physicsBody.isDynamic = true
        physicsBody.affectedByGravity = false
        physicsBody.categoryBitMask = enemyCategory
        physicsBody.contactTestBitMask = bulletCategory | playerCategory
        physicsBody.collisionBitMask = 0
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
    }
    
    // MARK: - Выстрел
    private func shoot() {
        // Ограничиваем количество пуль
        if activeBullets.count >= 3 { return } // Уменьшаем лимит пуль
        
        let bulletNode = SKNode()
        let bulletSize = CGSize(width: 4, height: 8) // Уменьшаем размер пули
        
        let bullet = SKShapeNode(rectOf: bulletSize, cornerRadius: 1)
        bullet.fillColor = .black
        bullet.strokeColor = .black
        bullet.lineWidth = 1
        bulletNode.addChild(bullet)
        
        bulletNode.position = CGPoint(x: playerTank.position.x,
                                    y: playerTank.position.y + 20)
        
        let bulletBody = SKPhysicsBody(rectangleOf: bulletSize)
        bulletBody.isDynamic = true
        bulletBody.affectedByGravity = false
        bulletBody.categoryBitMask = bulletCategory
        bulletBody.contactTestBitMask = enemyCategory
        bulletBody.collisionBitMask = 0
        bulletBody.mass = 0.1
        bulletBody.velocity = CGVector(dx: 0, dy: 400) // Задаём постоянную скорость
        bulletNode.physicsBody = bulletBody
        
        activeBullets.insert(bulletNode)
        addChild(bulletNode)
        
        // Автоматическое удаление через 1.5 секунды
        let removeAction = SKAction.sequence([
            SKAction.wait(forDuration: 1.5),
            SKAction.run { [weak self, weak bulletNode] in
                guard let self = self,
                      let bullet = bulletNode else { return }
                bullet.removeFromParent()
                self.activeBullets.remove(bullet)
            }
        ])
        bulletNode.run(removeAction)
    }
    
    // MARK: - touches
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if isPaused {
            // Проверяем нажатие на кнопку перезапуска
            if let restart = restartButton,
               restart.contains(location) {
                restartGame()
            }
            return
        }
        
        let nodesAtPoint = nodes(at: location)
        if nodesAtPoint.contains(where: { $0.name == "playerTank" }) {
            isTouchingTank = true
            shoot()
        } else {
            isMoving = true
            moveTankTo(point: location)
        }
        lastTouchLocation = location
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              !isPaused,
              isMoving else { return }
        
        let location = touch.location(in: self)
        moveTankTo(point: location)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isMoving = false
        isTouchingTank = false
    }
    
    // MARK: - Свободное перемещение танка
    private func moveTankTo(point: CGPoint) {
        // Ограничения движения
        let minY: CGFloat = 50
        let maxY: CGFloat = size.height * 0.4
        let margin: CGFloat = 40
        
        let targetX = min(max(point.x, margin), size.width - margin)
        let targetY = min(max(point.y, minY), maxY)
        
        let targetPoint = CGPoint(x: targetX, y: targetY)
        
        // Плавное движение с постоянной скоростью
        let currentPos = playerTank.position
        let distance = hypot(targetPoint.x - currentPos.x, targetPoint.y - currentPos.y)
        
        if distance < 1 { return } // Избегаем микродвижений
        
        // Вычисляем направление
        let dx = targetPoint.x - currentPos.x
        let dy = targetPoint.y - currentPos.y
        let normalizedDx = dx / distance
        let normalizedDy = dy / distance
        
        // Применяем движение
        let newX = currentPos.x + (normalizedDx * moveSpeed * 0.016) // 60 FPS
        let newY = currentPos.y + (normalizedDy * moveSpeed * 0.016)
        
        playerTank.position = CGPoint(x: newX, y: newY)
    }
    
    // MARK: - SKPhysicsContactDelegate
    func didBegin(_ contact: SKPhysicsContact) {
        let firstBody: SKPhysicsBody
        let secondBody: SKPhysicsBody
        
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            firstBody = contact.bodyA
            secondBody = contact.bodyB
        } else {
            firstBody = contact.bodyB
            secondBody = contact.bodyA
        }
        
        // Проверяем столкновение пули с врагом
        if firstBody.categoryBitMask == bulletCategory && 
           secondBody.categoryBitMask == enemyCategory {
            handleBulletEnemyCollision(bullet: firstBody.node, enemy: secondBody.node)
        }
        // Проверяем столкновение игрока с врагом
        else if (firstBody.categoryBitMask == playerCategory && 
                 secondBody.categoryBitMask == enemyCategory) ||
                (firstBody.categoryBitMask == enemyCategory && 
                 secondBody.categoryBitMask == playerCategory) {
            handlePlayerEnemyCollision()
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
        
        // Обновляем позицию танка если движемся
        if isMoving, let lastLocation = lastTouchLocation {
            moveTankTo(point: lastLocation)
        }
        
        // Обновляем башни врагов
        updateEnemyTurrets()
    }
    
    private func updateEnemyTurrets() {
        let visibleEnemies = enemyTanks.prefix(10)
        for enemy in visibleEnemies {
            updateEnemyTurret(enemy)
        }
    }
    
    private func updateEnemyTurret(_ enemy: SKNode) {
        guard let turret = enemy.childNode(withName: "turret") else { return }
        let dx = playerTank.position.x - enemy.position.x
        let dy = playerTank.position.y - enemy.position.y
        turret.zRotation = atan2(dy, dx) - .pi/2
    }
    
    // MARK: - Ограничиваем выход танка за рамки
    private func clampPlayerTankPosition() {
        // Учитываем половину габаритов танка (40×30 => половина 20×15)
        let halfW: CGFloat = 20
        let halfH: CGFloat = 15
        
        var pos = playerTank.position
        // По X
        if pos.x < halfW { pos.x = halfW }
        if pos.x > size.width - halfW { pos.x = size.width - halfW }
        
        // По Y
        if pos.y < halfH { pos.y = halfH }
        if pos.y > size.height - halfH { pos.y = size.height - halfH }
        
        playerTank.position = pos
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
        self.gameOverLabel = gameOverLabel // Сохраняем ссылку
        
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
        
        // Сбрасываем параметры
        score = 0
        playerLives = 3
        spawnCount = 0
        isMoving = false
        
        // Возвращаем танк на начальную позицию
        let startY = size.height * 0.2
        playerTank.position = CGPoint(x: size.width / 2, y: startY)
        
        // Возобновляем игру
        isPaused = false
    }
    
    // Добавим метод для очистки удалённых объектов
    override func didFinishUpdate() {
        super.didFinishUpdate()
        
        // Очищаем массив врагов от удалённых нодов
        enemyTanks.removeAll { $0.parent == nil }
        
        // Очищаем множество пуль от удалённых нодов
        activeBullets = activeBullets.filter { $0.parent != nil }
    }
}
