//
//  UsersTableViewController.swift
//  Random Users
//
//  Created by Wyatt Harrell on 4/10/20.
//  Copyright © 2020 Erica Sadun. All rights reserved.
//

import UIKit

class UsersTableViewController: UITableViewController {

    let userController = UserController()
    let cache = Cache<UUID,Data>()
    let photoFetchQueue = OperationQueue()
    var operationsDict: [UUID : Operation] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        userController.getUsers { (error) in
            if let error = error {
                print(error)
            } else {
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        }
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return userController.users.count
    }
    
    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let op = operationsDict[userController.users[indexPath.row].id!] {
            op.cancel()
        }
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath) as? UserTableViewCell else { return UITableViewCell() }

        loadImage(forCell: cell, forItemAt: indexPath)
        let name = "\(userController.users[indexPath.row].name.title) \(userController.users[indexPath.row].name.first) \(userController.users[indexPath.row].name.last)"
        cell.nameLabel.text = name

        return cell
    }
    
    private func loadImage(forCell cell: UITableViewCell, forItemAt indexPath: IndexPath) {
        
        guard let cell = cell as? UserTableViewCell else { return }
        
        let user = userController.users[indexPath.row]
        
        if let cache = cache.value(for: user.id!) {
            cell.profileImage.image = UIImage(data: cache)
            return
        } else {
            
            let fetchPhotoOperation = FetchPhotoOperation(user: user, imageType: .thumbnail)
            
            let cacheImageData = BlockOperation {
                if let imageData = fetchPhotoOperation.imageData {
                    self.cache.cache(value: imageData, for: user.id!)
                } else {
                    return
                }
            }

            let setCellImage = BlockOperation {
                DispatchQueue.main.async {
                    if self.tableView.indexPath(for: cell) == indexPath {
                        if let imageData = fetchPhotoOperation.imageData {
                            cell.profileImage.image = UIImage(data: imageData)
                        } else {
                            return
                        }
                    } else {
                        return
                    }
                }
            }

            cacheImageData.addDependency(fetchPhotoOperation)
            setCellImage.addDependency(fetchPhotoOperation)

            photoFetchQueue.addOperations([fetchPhotoOperation, cacheImageData, setCellImage], waitUntilFinished: false)
            operationsDict[user.id!] = fetchPhotoOperation
        }
        
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowUserDetailSegue" {
            guard let selected = tableView.indexPathForSelectedRow else { return }
            guard let UserDetailVC = segue.destination as? UserDetailViewController else { return }
            
            UserDetailVC.user = userController.users[selected.row]
            UserDetailVC.photoFetchQueue = photoFetchQueue
        }
    }
}
