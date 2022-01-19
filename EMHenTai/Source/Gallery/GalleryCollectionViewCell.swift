//
//  GalleryCollectionViewCell.swift
//  EMHenTai
//
//  Created by yuman on 2022/1/18.
//

import Foundation
import UIKit

class GalleryCollectionViewCell: UICollectionViewCell {
    
    private let imageView: UIImageView = {
        let img = UIImageView()
        img.contentMode = .scaleAspectFit
        return img
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        self.backgroundColor = .black
        contentView.backgroundColor = .black
        contentView.addSubview(imageView)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
        imageView.leftAnchor.constraint(equalTo: contentView.leftAnchor).isActive = true
        imageView.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
        imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
    }
    
    func updateImageWith(filePath: String) {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
            imageView.image = UIImage(data: data)
        }
    }
}