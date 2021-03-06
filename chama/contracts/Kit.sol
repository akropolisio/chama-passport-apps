/*
 * SPDX-License-Identitifer:    GPL-3.0-or-later
 *
 * This file requires contract dependencies which are licensed as
 * GPL-3.0-or-later, forcing it to also be licensed as such.
 *
 * This is the only file in your project that requires this license and
 * you are free to choose a different license for the rest of the project.
 */

pragma solidity 0.4.24;

import "@aragon/os/contracts/factory/DAOFactory.sol";
import "@aragon/os/contracts/apm/Repo.sol";
import "@aragon/os/contracts/lib/ens/ENS.sol";
import "@aragon/os/contracts/lib/ens/PublicResolver.sol";

import "@aragon/os/contracts/apm/APMNamehash.sol";
// import "@aragon/os/contracts/kernel/KernelConstants.sol";

import "@aragon/apps-voting/contracts/Voting.sol";
import "@aragon/apps-token-manager/contracts/TokenManager.sol";
import "@aragon/apps-shared-minime/contracts/MiniMeToken.sol";

// import "@aragon/apps-vault/contracts/?.sol";
// import "@aragon/apps-finance/contracts/?.sol";

import "./ChamaApp.sol";
import "../../common/contracts/IPassport.sol";
import "../../common/contracts/IChamaKit.sol";


contract KitBase is APMNamehash {
    ENS public ens;
    DAOFactory public fac;

    event DeployInstance(address dao);
    event InstalledApp(address appProxy, bytes32 appId);

    function KitBase(DAOFactory _fac, ENS _ens) {
        ens = _ens;

        // If no factory is passed, get it from on-chain bare-kit
        if (address(_fac) == address(0)) {
            bytes32 bareKit = apmNamehash("bare-kit");
            fac = KitBase(latestVersionAppBase(bareKit)).fac();
        } else {
            fac = _fac;
        }
    }

    function latestVersionAppBase(bytes32 appId) public view returns (address base) {
        Repo repo = Repo(PublicResolver(ens.resolver(appId)).addr(appId));
        (,base,) = repo.getLatest();

        return base;
    }
}


contract Kit is KitBase, IChamaKit {
    MiniMeTokenFactory tokenFactory;

    uint64 constant PCT = 10 ** 16;
    address constant ANY_ENTITY = address(-1);

    function Kit(ENS ens) KitBase(DAOFactory(0), ens) {
        tokenFactory = new MiniMeTokenFactory();

        // register kit (self) in the factory
        // bytes32 facAppId = apmNamehash("chama-factory");
        // IPassport factory = IPassport(dao.newAppInstance(facAppId, latestVersionAppBase(facAppId)));
        // factory.registerKit(this);
    }

    function newInstance() {
        Kernel dao = fac.newDAO(this);
        ACL acl = ACL(dao.acl());
        acl.createPermission(this, dao, dao.APP_MANAGER_ROLE(), this);

        address root = msg.sender;
        bytes32 appId = apmNamehash("chama");
        bytes32 idAppId = apmNamehash("passport");
        bytes32 votingAppId = apmNamehash("voting");
        bytes32 tokenManagerAppId = apmNamehash("token-manager");

        ChamaApp app = ChamaApp(dao.newAppInstance(appId, latestVersionAppBase(appId)));

        // address passportAddr = address(0x990268D34C896A220d6173662DeB802041252dF5);
        IPassport passport = IPassport(dao.newAppInstance(idAppId, latestVersionAppBase(idAppId)));
        // ERCProxy appProxy = ERCProxy(passportAddr);
        // IPassport passport = IPassport(passportAddr);
        // dao.setApp(dao.APP_ADDR_NAMESPACE(), idAppId, ERCProxy(passportAddr));
        // IPassport passport = IPassport(dao.setApp(dao.APP_ADDR_NAMESPACE(), idAppId, passportAddr));
        // passport.registerChama(/* TODO: root passport address */);

        Voting voting = Voting(dao.newAppInstance(votingAppId, latestVersionAppBase(votingAppId)));
        TokenManager tokenManager = TokenManager(dao.newAppInstance(tokenManagerAppId, latestVersionAppBase(tokenManagerAppId)));

        MiniMeToken token = tokenFactory.createCloneToken(MiniMeToken(0), 0, "App token", 0, "APP", true);
        token.changeController(tokenManager);

        // TODO: vault


        // Initialize apps
        app.initialize();
        passport.initialize(/* TODO: root passport address */);
        tokenManager.initialize(token, true, 0);
        voting.initialize(token, 50 * PCT, 20 * PCT, 1 days);

        acl.createPermission(this, tokenManager, tokenManager.MINT_ROLE(), this);
        tokenManager.mint(root, 1); // Give one token to root

        acl.createPermission(ANY_ENTITY, voting, voting.CREATE_VOTES_ROLE(), root);

        // acl.createPermission(voting, passport, passport.REGISTER_IDENTITY_ROLE(), voting);
        acl.createPermission(voting, passport, keccak256("REGISTER_IDENTITY_ROLE"), voting);
        // acl.createPermission(ANY_ENTITY, IPassport(passportAddr), IPassport(passportAddr).REGISTER_IDENTITY_ROLE(), root);
        // acl.createPermission(ANY_ENTITY, passport, keccak256("REGISTER_IDENTITY_ROLE"), root);

        acl.grantPermission(voting, tokenManager, tokenManager.MINT_ROLE());

        // acl.createPermission(ANY_ENTITY, appFac, appFac.CREATE_DAO_ROLE(), root);


        // Clean up permissions
        acl.grantPermission(root, dao, dao.APP_MANAGER_ROLE());
        acl.revokePermission(this, dao, dao.APP_MANAGER_ROLE());
        acl.setPermissionManager(root, dao, dao.APP_MANAGER_ROLE());

        acl.grantPermission(root, acl, acl.CREATE_PERMISSIONS_ROLE());
        acl.revokePermission(this, acl, acl.CREATE_PERMISSIONS_ROLE());
        acl.setPermissionManager(root, acl, acl.CREATE_PERMISSIONS_ROLE());

        // address me = address(this);

        DeployInstance(dao);
    }
}
