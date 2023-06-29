// erc20 methods
methods {
    name()                                => DISPATCHER(true)
    symbol()                              => DISPATCHER(true)
    decimals()                            => DISPATCHER(true)
    totalSupply()                         => DISPATCHER(true)
    balanceOf(address)                    => DISPATCHER(true)
    allowance(address,address)            => DISPATCHER(true)
    approve(address,uint256)              => DISPATCHER(true)
    transfer(address,uint256)             => DISPATCHER(true)
    transferFrom(address,address,uint256) => DISPATCHER(true)
}
