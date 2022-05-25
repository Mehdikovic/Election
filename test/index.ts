import { expect } from "chai";
import { BigNumberish, Signer } from "ethers";
import { ethers } from "hardhat";
import { Election, WakandaToken } from "../typechain";

let ElectionFactory
let election: Election

let WakandaFactory
let wakanda: WakandaToken

let voter1: Signer
let voter1Addr: string

let voter2: Signer
let voter2Addr: string

let voter3: Signer
let voter3Addr: string

describe("Election", function () {
  it("should deploy and add one candidate", async function () {

    WakandaFactory = await ethers.getContractFactory("WakandaToken")
    wakanda = await WakandaFactory.deploy()
    await wakanda.deployed()

    ElectionFactory = await ethers.getContractFactory("Election")
    election = await ElectionFactory.deploy(wakanda.address)
    await election.deployed()

    let tx = await election.registerCandidate("Name1", "Cult1", 20)
    let rec = await tx.wait()
    let id = rec.events?.[0].args?.id

    expect(id).to.be.eq(1)

    let candidate = await election.sortedCandidates(0)
    expect(candidate.name).to.be.eq("Name1")
    expect(candidate.cult).to.be.eq("Cult1")
    expect(candidate.age).to.be.eq(20)
    expect(candidate.votes).to.be.eq(0)

    let accounts = await ethers.getSigners()

    voter1 = accounts[1]
    voter1Addr = await voter1.getAddress()

    voter2 = accounts[2]
    voter2Addr = await voter2.getAddress()

    voter3 = accounts[3]
    voter3Addr = await voter3.getAddress()
  });

  it("should add two more candidates", async () => {
    let tx = await election.registerCandidate("Name2", "Cult2", 25)
    let rec = await tx.wait()
    let id = rec.events?.[0].args?.id

    expect(id).to.be.eq(2)
    let candidate = await election.sortedCandidates(1)
    expect(candidate.name).to.be.eq("Name2")
    expect(candidate.cult).to.be.eq("Cult2")
    expect(candidate.age).to.be.eq(25)
    expect(candidate.votes).to.be.eq(0)

    tx = await election.registerCandidate("Name3", "Cult3", 30)
    rec = await tx.wait()
    id = rec.events?.[0].args?.id

    expect(id).to.be.eq(3)
    candidate = await election.sortedCandidates(2)
    expect(candidate.name).to.be.eq("Name3")
    expect(candidate.cult).to.be.eq("Cult3")
    expect(candidate.age).to.be.eq(30)
    expect(candidate.votes).to.be.eq(0)
  })

  it("should fire an event for the first candidate", async () => {
    let candidateId = 1

    await wakanda.register(voter1Addr)
    await wakanda.connect(voter1).approve(election.address, toEth(1))

    expect(await election.userCastedVote(voter1Addr, candidateId)).to.be.eq(false)

    expect((await election.id2candidates(candidateId)).votes).to.be.eq(0)

    await (await election.connect(voter1).castVote(candidateId)).wait()

    expect((await election.getSortedCandidates())[0].votes).to.be.eq(1)
    expect((await election.id2candidates(candidateId)).votes).to.be.eq(1)
    expect(await election.userCastedVote(voter1Addr, candidateId)).to.be.eq(true)
    expect((await election.getVotersOfCandidate(candidateId))[0]).to.be.eq(voter1Addr)
    expect((await election.getCandidatesOfVoter(voter1Addr))[0]).to.be.eq(candidateId)
  })

  it("should fire an event for the first candidate", async () => {
    let candidateId = 2

    await wakanda.register(voter1Addr)
    await wakanda.connect(voter1).approve(election.address, toEth(1))

    await wakanda.register(voter2Addr)
    await wakanda.connect(voter2).approve(election.address, toEth(1))
    
    expect(await election.userCastedVote(voter1Addr, candidateId)).to.be.eq(false)
    expect(await election.userCastedVote(voter2Addr, candidateId)).to.be.eq(false)

    expect((await election.id2candidates(candidateId)).votes).to.be.eq(0)

    await (await election.connect(voter1).castVote(candidateId)).wait()
    await (await election.connect(voter2).castVote(candidateId)).wait()

    expect((await election.getSortedCandidates())[0].votes).to.be.eq(2)
    expect((await election.id2candidates(candidateId)).votes).to.be.eq(2)
    expect(await election.userCastedVote(voter1Addr, candidateId)).to.be.eq(true)
    expect(await election.userCastedVote(voter2Addr, candidateId)).to.be.eq(true)
    expect((await election.getVotersOfCandidate(candidateId))[0]).to.be.eq(voter1Addr)
    expect((await election.getVotersOfCandidate(candidateId))[1]).to.be.eq(voter2Addr)
    expect((await election.getCandidatesOfVoter(voter1Addr))[1]).to.be.eq(candidateId)
    expect((await election.getCandidatesOfVoter(voter2Addr))[0]).to.be.eq(candidateId)
  })

  it("should add candidate num 4", async () => {
    let tx = await election.registerCandidate("Name4", "Cult4", 43)
    let rec = await tx.wait()
    let candidateId = rec.events?.[0].args?.id

    expect(candidateId).to.be.eq(4)
    let candidate = await election.sortedCandidates(3)
    expect(candidate.name).to.be.eq("Name4")
    expect(candidate.cult).to.be.eq("Cult4")
    expect(candidate.age).to.be.eq(43)
    expect(candidate.votes).to.be.eq(0)

    await wakanda.register(voter1Addr)
    await wakanda.connect(voter1).approve(election.address, toEth(1))

    await wakanda.register(voter2Addr)
    await wakanda.connect(voter2).approve(election.address, toEth(1))

    await wakanda.register(voter3Addr)
    await wakanda.connect(voter3).approve(election.address, toEth(1))

    rec = await (await election.connect(voter1).castVote(candidateId)).wait()
    rec = await (await election.connect(voter2).castVote(candidateId)).wait()
    rec = await (await election.connect(voter3).castVote(candidateId)).wait()

    expect((await election.id2candidates(candidateId)).votes).to.be.eq(3)
    expect((await election.getSortedCandidates())[0].votes).to.be.eq(3)
    expect((await election.getVotersOfCandidate(candidateId))[0]).to.be.eq(voter1Addr)
    expect((await election.getVotersOfCandidate(candidateId))[1]).to.be.eq(voter2Addr)
    expect((await election.getVotersOfCandidate(candidateId))[2]).to.be.eq(voter3Addr)
  })

  it("should check for the owner", async () => {
    let depoyer = await (await ethers.getSigners())[0].getAddress()
    expect(await election.owner()).to.be.eq(depoyer)
  })
});


export function toEth(value: BigNumberish) {
  return ethers.utils.parseEther(value.toString());
}