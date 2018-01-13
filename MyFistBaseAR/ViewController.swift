//
//  ViewController.swift
//  MyFistBaseAR
//
//  Created by yejunyou on 2018/1/13.
//  Copyright © 2018年 yejunyou. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet weak var sessionInfoLabel: UILabel!
    @IBOutlet weak var sessionInfoView: UIView!
    @IBOutlet weak var sceneView: ARSCNView!
    
    
    
    override func viewDidAppear(_ animated: Bool) {
        /// Tag:StartARSesstion
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("""
                    你的手机不支持唉，扔了吧。
                    搞个A9芯片，iOS11以上版本的手机试试Ha
                """)
        }
        
        /// 设置前摄像头，支持位置、方向追踪，平面检测
        let configuration = ARWorldTrackingConfiguration()
        // configuration.planeDetection = ARWorldTrackingConfiguration.PlaneDetection.horizontal
        // 上面这句可以简写成如下
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
        
        // 用代理检测平面锚点个数，提供UI反馈
        sceneView.delegate = self
        
        // 当用户长时间没有交互，（没有触摸屏幕或者按钮），再次屏幕会没有反应，设置true会有反应
        UIApplication.shared.isIdleTimerDisabled = true
        
        // 开发的时候设置true，用于查看实时性能指标
        sceneView.showsStatistics = true
        
        // 展示坐标系
        sceneView.debugOptions = ARSCNDebugOptions.showWorldOrigin
        
        // 特征点
        sceneView.debugOptions = ARSCNDebugOptions.showFeaturePoints
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.session.pause()
    }
    
    /// - Tag:PlaceARContent 放置AR文本
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // 仅仅当通过平面检测找到了锚点，才放置文本
        guard let planeAnchor = anchor as? ARPlaneAnchor else {return}
        
        // 用位置和文本信息，创建一个SceneKti平面来可视化平面锚点
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height:CGFloat(planeAnchor.extent.z))
        plane.firstMaterial?.diffuse.contents = UIColor.red
        let planeNode = SCNNode(geometry:plane)
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        // SCNPlane 在它的坐标系里是垂直空间，旋转平面去匹配水平方向的ARPlaneAnchor
        planeNode.eulerAngles.x = -.pi/2
        
        // 半透明设置
        planeNode.opacity = 0.2048
        
        
        // 添加到aRKit管理节点，当平面被估计为连续的（扩展）的时候，能够追踪到平面的锚点
        node .addChildNode(planeNode)
    }
    
    /// - Tag:更新AR内容
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // 仅仅当平面锚点和node在设置匹配的时候，更新内容
        // 设置是在上面这个方法里完成的shift
        guard   let planeAnchor = anchor as? ARPlaneAnchor,
                let planeNode = node.childNodes.first,
                let plane = planeNode.geometry as? SCNPlane
            else {return}
        
        // 平面估计转换到平面中心，与锚点trnsform相关
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        // 平面预测延伸平面的size，后者合并之前检测到的片面，组成一个更大的平面。
        // 对于后者，ARSCNView会为同一个平面删除重复的node，然后调用本方法更新保留下来的平面的size
        plane.width = CGFloat(planeAnchor.extent.x)
        plane.height = CGFloat(planeAnchor.extent.z)
    }

    // MARK: - ARSCNViewDelegate
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        sessionInfoLabel.text = "老子检测失败啦\(error.localizedDescription)"
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        sessionInfoLabel.text = "老子检测被中断啦"
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        sessionInfoLabel.text = "中断啦结束啦，重置检测，继续干！！！"
        resetTracking()
    }
    
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        updateSessionInfoLabel(for: session.currentFrame!, trackingState: camera.trackingState)
    }
    
    /// MARK - private methods
    private func updateSessionInfoLabel(for frame:ARFrame, trackingState:ARCamera.TrackingState){
        let message:String
        
        switch trackingState {
        case .normal where frame.anchors.isEmpty:
            message = "木有检测到水平面"
            
        case .normal: // 这个状态更新不及时啊,可能更新调用的时机不对
            message = "正常模式( ⊙ o ⊙ )啊！"
            
        case .notAvailable:
            message = "追踪不可用啊"
            
        case .limited(.excessiveMotion):
            message = "追踪受到限制啦-慢一点呗"
            
        case .limited(.insufficientFeatures):
            message = "检测不到细节，对准一点表面细节，或者加强光线"
            
        case .limited(.initializing):
            message = "初始化 ARSession ..."
        }
        
        sessionInfoLabel.text = message
        sessionInfoView.isHidden = message.isEmpty
    }
    
    private func resetTracking(){
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = .horizontal
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }
}
