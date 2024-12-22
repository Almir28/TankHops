//
//  GameViewController.swift
//  TankHops
//
//  Created by Almir Khialov on 22.12.2024.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let skView = self.view as? SKView {
            skView.ignoresSiblingOrder = true
            skView.showsFPS = true
            skView.showsNodeCount = true
            
            let scene = GameScene(size: skView.bounds.size)
            scene.scaleMode = .aspectFill
            
            // Оптимизация рендеринга
            skView.preferredFramesPerSecond = 60
            skView.isAsynchronous = true
            
            skView.presentScene(scene)
        }
    }
    
    // Разрешённые ориентации
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        // Для iPhone — все, кроме «вверх ногами» (по умолчанию)
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            // Для iPad
            return .all
        }
    }

    // Скрываем статус-бар
    override var prefersStatusBarHidden: Bool {
        return true
    }
}
